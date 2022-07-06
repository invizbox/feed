""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from contextlib import suppress
from json import JSONDecodeError
from math import floor
from re import compile as re_compile
from subprocess import CalledProcessError, run, PIPE
from threading import Lock
from time import time
from uuid import uuid4

from bottle import Bottle, request, response
from bottle_jwt import jwt_auth_required

from plugins.plugin_jwt import JWT_PLUGIN
from plugins.plugin_uci import UCI_PLUGIN
from plugins.uci import UciException
from utils.validate import validate_option

KNOWN_NETWORKS_PKG = "known_networks"
NETWORK_PKG = "network"
WIRELESS_PKG = "wireless"
LOGGER = logging.getLogger(__name__)

INTERNET_APP = Bottle()
INTERNET_APP.install(JWT_PLUGIN)
INTERNET_APP.install(UCI_PLUGIN)
INTERNET_APP.scan_results = {"wifiHotspots": [], "timestamp": 0}
INTERNET_APP.re_ssid = re_compile(r'ESSID*: "?(.*[^(?:"$)])')
INTERNET_APP.re_quality = re_compile(r'.*Quality: (.*)/(.*)$')
INTERNET_APP.re_encryption = re_compile(r'Encryption: (.*)')
INTERNET_APP.lock = Lock()


def validate_internet(internet, uci):
    """Validate an internet setup"""
    valid = True
    try:
        valid &= validate_option("boolean", internet["cable"])
        if internet["cable"]:
            valid &= validate_option("string", internet["interfaceName"])
        else:
            valid &= validate_option("string", internet["ssid"])
            valid &= validate_option("string", internet["encryption"])
            valid &= internet["encryption"] in ["none", "wep", "psk-mixed"]
            if internet["encryption"] != "none":
                if "key" in internet:
                    valid &= validate_option("string", internet["key"])
                    valid &= 8 <= len(internet["key"].encode('utf-8')) <= 63
                else:
                    known_hotspots = [hotspot["ssid"] for hotspot in uci.get_package(KNOWN_NETWORKS_PKG)]
                    valid &= internet["ssid"] in known_hotspots
    except KeyError:
        valid = False
    return valid


@INTERNET_APP.get('/system/internet')
@jwt_auth_required
def get_internet(uci):
    """Display the current information used to connect to the internet"""
    try:
        network_uci = uci.get_package(NETWORK_PKG)
        internet = next({
            "cable": True,
            "interfaceName": network["ifname"] if "ifname" in network else ""
        } for network in network_uci if network[".type"] == "interface" and network["id"] == "wan")
        if internet["interfaceName"] != "":
            return internet
        wireless = next(section for section in uci.get_package(WIRELESS_PKG) if
                        section[".type"] == "wifi-iface" and section["network"] == "wan")
        internet = {
            "cable": False,
            "ssid": wireless["ssid"] if "ssid" in wireless else "",
            "encryption": wireless["encryption"] if "encryption" in wireless else "none",
        }
        if "key" in wireless:
            internet["key"] = wireless["key"]
        return internet
    except (StopIteration, UciException):
        response.status = 400
        return "Error getting internet details"


def update_known_hotspots(updated_internet, uci):
    """Helper function to update the known_networks config with the new hotspot info"""
    try:
        hotspots_uci = uci.get_package(KNOWN_NETWORKS_PKG)
        known_hotspot = next(hotspot for hotspot in hotspots_uci if hotspot["ssid"] == updated_internet["ssid"])
        if updated_internet["encryption"] != "none":
            if "key" not in updated_internet and "key" in known_hotspot:
                updated_internet["key"] = known_hotspot["key"]
            uci.set_option(KNOWN_NETWORKS_PKG, known_hotspot["id"], "key", updated_internet["key"])
        elif "key" in known_hotspot:
            uci.delete_option(KNOWN_NETWORKS_PKG, known_hotspot["id"], "key")
    except StopIteration:
        known_hotspot = {".type": "network", "id": uuid4().hex, "ssid": updated_internet["ssid"]}
        if updated_internet["encryption"] != "none":
            known_hotspot["key"] = updated_internet["key"]
        uci.add_config(KNOWN_NETWORKS_PKG, known_hotspot)
    return updated_internet


@INTERNET_APP.put('/system/internet')
@jwt_auth_required
def set_internet(uci):
    """Set the information required to connect to the internet over cable or wireless"""
    try:
        updated_internet = dict(request.json)
        if not validate_internet(updated_internet, uci):
            response.status = 400
            return "Empty or invalid fields"
        network_uci = uci.get_package(NETWORK_PKG)
        for network in network_uci:
            if network[".type"] == "interface" and network["id"] == "wan":
                if updated_internet["cable"]:
                    uci.set_option(NETWORK_PKG, network["id"], "ifname", updated_internet["interfaceName"])
                else:
                    if "ifname" in network:
                        uci.delete_option(NETWORK_PKG, network["id"], "ifname")
        wireless_uci = uci.get_package(WIRELESS_PKG)
        found_sta_wireless = False
        if not updated_internet["cable"]:
            updated_internet = update_known_hotspots(updated_internet, uci)
        for wireless in wireless_uci:
            if wireless[".type"] == "wifi-iface" and wireless["network"] == "wan":
                found_sta_wireless = True
                if updated_internet["cable"]:
                    uci.delete_config(WIRELESS_PKG, wireless["id"])
                else:
                    uci.set_option(WIRELESS_PKG, wireless["id"], "ssid", updated_internet["ssid"])
                    uci.set_option(WIRELESS_PKG, wireless["id"], "key",
                                   updated_internet["key"] if updated_internet["encryption"] != "none" else "none")
                    uci.set_option(WIRELESS_PKG, wireless["id"], "encryption", updated_internet["encryption"])
                    uci.set_option(WIRELESS_PKG, wireless["id"], "mode", "sta")
        if not updated_internet["cable"] and not found_sta_wireless:
            uci.add_config(WIRELESS_PKG, {
                ".type": "wifi-iface",
                "id": "wan",
                "device": "radio1",
                "network": "wan",
                "mode": "sta",
                "ssid": updated_internet["ssid"],
                "encryption": updated_internet["encryption"],
                "key": updated_internet["key"] if updated_internet["encryption"] != "none" else "none"})
        uci.persist(NETWORK_PKG)
        uci.persist(WIRELESS_PKG)
        with suppress(FileNotFoundError):
            run(["/etc/init.d/wifiwatch", "restart"], check=False)
        run(["/etc/init.d/network", "reload"], check=False)
        uci.persist(KNOWN_NETWORKS_PKG)
        return dict(request.json)
    except (JSONDecodeError, UciException, KeyError, TypeError):
        response.status = 400
        return "Invalid content"


@INTERNET_APP.get('/system/internet/known_wifi_hotspots')
@jwt_auth_required
def get_known_hotspots(uci):
    """Get known hotspots from uci"""
    try:
        hotspots_uci = uci.get_package(KNOWN_NETWORKS_PKG)
        return {"wifiHotspots": [{"id": hotspot["id"], "ssid": hotspot["ssid"]} for hotspot in hotspots_uci]}
    except UciException:
        response.status = 404
        return "Error getting known WiFi hotspots"


@INTERNET_APP.get('/system/internet/known_wifi_hotspots/<hotspot_id>')
@jwt_auth_required
def get_known_hotspot(hotspot_id, uci):
    """Get a known WiFi hotspot"""
    try:
        hotspots_uci = uci.get_package(KNOWN_NETWORKS_PKG)
        hotspot = next(hotspot for hotspot in hotspots_uci if hotspot["id"] == hotspot_id)
        result = {"id": hotspot["id"], "ssid": hotspot["ssid"]}
        if "key" in hotspot:
            result["key"] = hotspot["key"]
        return result
    except (UciException, StopIteration):
        response.status = 404
        return "Invalid WiFi hotspot"


@INTERNET_APP.get('/system/internet/wifi_hotspots')
@jwt_auth_required
def get_scan_results():
    """List the results of the last WiFi scan if there was any"""
    return INTERNET_APP.scan_results


def parse_hotspots(output):
    """Helper function to parse hotspots from iwinfo output"""
    hotspots = {}
    hotspot = {}
    ssid = "unknown"
    for line in map(str.strip, output.splitlines()):
        if line.startswith("ESSID"):
            ssid = INTERNET_APP.re_ssid.search(line).group(1)
            hotspot = {"ssid": ssid}
        if line.startswith("Signal"):
            quality = INTERNET_APP.re_quality.search(line)
            if int(quality.group(1)) > 0 and int(quality.group(2)) > 0:
                hotspot["quality"] = floor((100 / int(quality.group(2))) * int(quality.group(1)))
            else:
                hotspot["quality"] = "unknown"
        if line.startswith("Encryption"):
            hotspot["encryption"] = "psk-mixed"
            encryption = INTERNET_APP.re_encryption.search(line)
            if encryption.group(1) == "none":
                hotspot["encryption"] = "none"
            elif "WPA" not in encryption.group(1):
                hotspot["encryption"] = "wep"
            if ssid in hotspots and hotspot["quality"] > hotspots[ssid]["quality"]:
                hotspots[ssid] = hotspot
            elif ssid not in hotspots and ssid != "unknown":
                hotspots[ssid] = hotspot
    return hotspots


@INTERNET_APP.post('/system/internet/wifi_hotspots')
@jwt_auth_required
def scan():
    """Scan and list nearby WiFi hotspots"""
    if INTERNET_APP.lock.acquire(False):  # pylint: disable=R1732
        try:
            with suppress(FileNotFoundError):
                run(["/etc/init.d/wifiwatch", "restart"], check=False)
            ubus_process = run(["iwinfo", "wlan0", "scan"], stdout=PIPE, stderr=PIPE, timeout=15, check=True)
            output = ubus_process.stdout.decode()
            if output.strip() == "Scanning not possible":
                response.status = 503
                return "WiFi scan already in progress"
            hotspots = parse_hotspots(output)
            INTERNET_APP.scan_results = {
                "wifiHotspots": sorted([value for _, value in hotspots.items()], key=lambda x: x["quality"],
                                       reverse=True),
                "timestamp": int(time())
            }
            return INTERNET_APP.scan_results
        except CalledProcessError:
            response.status = 503
            return "WiFi scan already in progress"
        finally:
            INTERNET_APP.lock.release()
    else:
        response.status = 503
        return "WiFi scan already in progress"
