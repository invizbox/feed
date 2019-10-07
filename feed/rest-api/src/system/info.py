""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from subprocess import run, PIPE
from os import system
from socket import error, socket, timeout, AF_INET, SOCK_STREAM
from json.decoder import JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, response, json_loads, request
from plugins.plugin_uci import UCI_PLUGIN, UCI_ROM_PLUGIN
from plugins.uci import UciException
from plugins.plugin_jwt import JWT_PLUGIN


NETWORK_PKG = "network"
UPDATE_PKG = "update"
WIRELESS_PKG = "wireless"
LOGGER = logging.getLogger(__name__)

INFO_APP = Bottle()
INFO_APP.install(JWT_PLUGIN)
INFO_APP.install(UCI_PLUGIN)
INFO_APP.install(UCI_ROM_PLUGIN)


@INFO_APP.get('/system/info/generic')
@jwt_auth_required
def get_generic_info(uci, uci_rom):
    """Endpoint to get access the fixed properties of the device
    Model
    Hostname
    Firmware Version: current and reset
    """
    try:
        ubus_process = run(["ubus", "call", "system", "board"], stdout=PIPE, stderr=PIPE, timeout=5)
        system_json = json_loads(ubus_process.stdout)
        try:
            firmware_version = uci.get_option(UPDATE_PKG, "version", "firmware") or "unknown"
        except UciException:
            firmware_version = "unknown"
        try:
            rom_firmware_version = uci_rom.get_option(UPDATE_PKG, "version", "firmware") or "unknown"
        except UciException:
            rom_firmware_version = "unknown"
        try:
            new_firmware_version = uci.get_option(UPDATE_PKG, "version", "new_firmware") or "unknown"
        except UciException:
            new_firmware_version = "unknown"
        try:
            support_url = uci.get_option(UPDATE_PKG, "urls", "support_url")
        except UciException:
            support_url = ""
        try:
            support_email = uci.get_option(UPDATE_PKG, "urls", "support_email")
        except UciException:
            support_email = ""
        return {"info": {"currentFirmware": firmware_version,
                         "resetFirmware": rom_firmware_version,
                         "newFirmware": new_firmware_version,
                         "kernel": system_json["kernel"],
                         "hostName": system_json["hostname"],
                         "model": system_json["model"],
                         "ports": ["1", "2", "3", "4"] if "Pro" in system_json["model"] else ["LAN"],
                         "support": {"url": support_url, "email": support_email}}}
    except JSONDecodeError:
        response.status = 400
        return "Error getting information"


@INFO_APP.get('/system/info/state')
@jwt_auth_required
def get_stateful_info():
    """Endpoint to get access the changing properties of the device
    Local Time
    Uptime
    memory
    """
    try:
        ubus_process = run(["ubus", "call", "system", "info"], stdout=PIPE, stderr=PIPE, timeout=5)
        system_json = json_loads(ubus_process.stdout)
        return {"info": system_json}
    except JSONDecodeError:
        response.status = 400
        return "Error getting information"


def receive_all(sock, buffer_size=1000):
    """read all available on a socket"""
    buf = sock.recv(buffer_size)
    while buf:
        yield buf.decode()
        if len(buf) < buffer_size:
            break
        buf = sock.recv(buffer_size)


def tor_up():
    """call the Tor admin interface a get a status"""
    try:
        with socket(AF_INET, SOCK_STREAM) as tor_socket:
            tor_socket.settimeout(1)
            tor_socket.connect(("127.0.0.1", 9051))
            tor_socket.send(b'AUTHENTICATE ""\r\n')
            if not ''.join(receive_all(tor_socket)):
                return False
            tor_socket.send(b'GETINFO network-liveness\r\n')
            tor_response = ''.join(receive_all(tor_socket))
            if not tor_response.startswith("250") or "=up" not in tor_response:
                return False
            return True
    except (timeout, error):
        return False


def check_file_content(filename, expected_content):
    """helper function to check a file content"""
    correct_content = False
    try:
        with open(filename, "r") as quick_read_file:
            correct_content = quick_read_file.readline().rstrip() == expected_content
    except (FileNotFoundError, IOError):
        pass
    return correct_content


@INFO_APP.get('/system/info/connectivity')
@jwt_auth_required
def get_connectivity_info(uci):
    """Endpoint to get access the connectivity properties of the device"""
    try:
        network_uci = uci.get_package(NETWORK_PKG)
        sta_iface = ""
        internet_connected = False
        try:
            sta_iface = next(network["ifname"] if "ifname" in network else ""
                             for network in network_uci if network[".type"] == "interface" and network["id"] == "wan")
        except StopIteration:
            pass
        if sta_iface == "":
            wireless_uci = uci.get_package(WIRELESS_PKG)
            try:
                sta_iface = next(network["ifname"] if "ifname" in network else "" for network in wireless_uci
                                 if network[".type"] == "wifi-iface" and network["id"] == "wan")
            except StopIteration:
                pass
        if sta_iface != "":
            internet_connected = system(f"ip -f inet -o addr show {sta_iface} | grep [i]net > /dev/null") == 0
        return {"connectivity": {"device_ip": request.environ.get('REMOTE_ADDR'),
                                 "internet": internet_connected,
                                 "lan_tor": tor_up(),
                                 "lan_vpn1": check_file_content("/tmp/openvpn/1/status", "up"),
                                 "lan_vpn2": check_file_content("/tmp/openvpn/2/status", "up"),
                                 "lan_vpn3": check_file_content("/tmp/openvpn/3/status", "up"),
                                 "lan_vpn4": check_file_content("/tmp/openvpn/4/status", "up")}}
    except (FileNotFoundError, IOError):
        response.status = 400
        return "Error getting connectivity information"
