""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from os import getenv
from subprocess import run, PIPE
from socket import error, socket, timeout, AF_INET, SOCK_STREAM
from json.decoder import JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, response, json_loads, request
from plugins.plugin_uci import UCI_PLUGIN, UCI_ROM_PLUGIN
from plugins.uci import UciException
from plugins.plugin_jwt import JWT_PLUGIN


NETWORK_PKG = "network"
REST_API_PKG = "rest-api"
UPDATE_PKG = "update"
WIRELESS_PKG = "wireless"
LOGGER = logging.getLogger(__name__)

INFO_APP = Bottle()
INFO_APP.install(JWT_PLUGIN)
INFO_APP.install(UCI_PLUGIN)
INFO_APP.install(UCI_ROM_PLUGIN)


def get_mac(filename):
    """Helper function to get the MAC address from a file"""
    try:
        with open(filename, encoding="utf-8") as my_file:
            return my_file.readline().rstrip().upper()
    except FileNotFoundError:
        return ''


def get_uci_info(uci, package, section, option):
    """Helper function to get the value from UCI"""
    try:
        return uci.get_option(package, section, option) or "unknown"
    except UciException:
        return "unknown"


@INFO_APP.get('/system/info/generic')
@jwt_auth_required
def get_generic_info(uci, uci_rom):
    """Get the device properties"""
    try:
        ubus_process = run(["ubus", "call", "system", "board"], stdout=PIPE, stderr=PIPE, timeout=5, check=False)
        system_json = json_loads(ubus_process.stdout)
        model = getenv("DEVICE_PRODUCT", "InvizBox 2")
        mac_addresses = {"ethernet": "", "wifi24GHz": "", "wifi5GHz": ""}
        if model == "InvizBox Go":
            mac_addresses["wifi24GHz"] = get_mac("/sys/devices/platform/1e140000.pcie/pci0000:00/0000:00:00.0"
                                                 "/0000:01:00.0/net/wlan0/address")
        elif model == "InvizBox 2":
            mac_addresses["ethernet"] = get_mac("/sys/devices/platform/soc/1c30000.ethernet/net/eth0/address")
            mac_addresses["wifi24GHz"] = get_mac("/sys/devices/platform/soc/1c1b000.usb/usb2/2-1/2-1:1.0/ieee80211/phy1"
                                                 "/addresses")
            mac_addresses["wifi5GHz"] = get_mac("/sys/devices/platform/soc/1c10000.mmc/mmc_host/mmc1/mmc1:0001"
                                                "/mmc1:0001:1/ieee80211/phy0/addresses")
        try:
            admin_interface_version = ''
            with open("/usr/lib/opkg/info/admin-interface.control", encoding="utf-8") as admin_interface_file:
                for line in admin_interface_file.readlines():
                    if line.startswith("Version:"):
                        admin_interface_version = line.strip().split()[1].replace('-', '.')
                        break
        except FileNotFoundError:
            pass
        firmware_version = get_uci_info(uci, UPDATE_PKG, "version", "firmware")
        rom_firmware_version = get_uci_info(uci_rom, UPDATE_PKG, "version", "firmware")
        new_firmware_version = get_uci_info(uci, UPDATE_PKG, "version", "new_firmware")
        api_version = get_uci_info(uci, REST_API_PKG, "version", "api")
        ports = ["LAN"]
        if model == "InvizBox 2 Pro":
            ports = ["1", "2", "3", "4"]
        if model == "InvizBox Go":
            ports = []
        return {"info": {"currentFirmware": firmware_version,
                         "resetFirmware": rom_firmware_version,
                         "newFirmware": new_firmware_version,
                         "api": api_version,
                         "adminInterface": admin_interface_version,
                         "kernel": system_json["kernel"],
                         "hostName": system_json["hostname"],
                         "macAddresses": mac_addresses,
                         "model": model,
                         "ports": ports}}
    except JSONDecodeError:
        response.status = 400
        return "Error getting information"


@INFO_APP.get('/system/info/state')
@jwt_auth_required
def get_stateful_info():
    """Get the state of the device"""
    try:
        ubus_process = run(["ubus", "call", "system", "info"], stdout=PIPE, stderr=PIPE, timeout=5, check=False)
        system_json = json_loads(ubus_process.stdout)
        return {"info": system_json}
    except JSONDecodeError:
        response.status = 400
        return "Error getting information"


def receive_all(sock, buffer_size=1000):
    """Read all available on a socket"""
    buf = sock.recv(buffer_size)
    while buf:
        yield buf.decode()
        if len(buf) < buffer_size:
            break
        buf = sock.recv(buffer_size)


def tor_up():
    """Call the Tor admin interface a get a status"""
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
    """Helper function to check a file content"""
    correct_content = False
    try:
        with open(filename, "r", encoding="utf-8") as quick_read_file:
            correct_content = quick_read_file.readline().rstrip() == expected_content
    except (FileNotFoundError, IOError):
        pass
    return correct_content


@INFO_APP.get('/system/info/connectivity')
@jwt_auth_required
def get_connectivity_info():
    """Get the connectivity properties of the device"""
    try:
        ip_route = run(["ip", "route"], stdout=PIPE, stderr=PIPE, timeout=5, check=False)
        invizbox_ip = next((line.strip().split(' ')[-1] for line in ip_route.stdout.decode('ascii').splitlines()
                            if line.startswith("default")), "")
        return {"connectivity": {"captive": invizbox_ip != "" and check_file_content("/tmp/currently-captive", "true"),
                                 "deviceIp": request.environ.get('REMOTE_ADDR'),
                                 "invizboxIp": invizbox_ip,
                                 "lan_tor": invizbox_ip != "" and tor_up(),
                                 "lan_vpn1": invizbox_ip != "" and check_file_content("/tmp/openvpn/1/status", "up"),
                                 "lan_vpn2": invizbox_ip != "" and check_file_content("/tmp/openvpn/2/status", "up"),
                                 "lan_vpn3": invizbox_ip != "" and check_file_content("/tmp/openvpn/3/status", "up"),
                                 "lan_vpn4": invizbox_ip != "" and check_file_content("/tmp/openvpn/4/status", "up")}}
    except (FileNotFoundError, IOError):
        response.status = 400
        return "Error getting connectivity information"
