""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from subprocess import run
from json.decoder import JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, request, response
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.plugin_uci import UCI_PLUGIN
from plugins.uci import UciException
from utils.validate import validate_option

NETWORK_PKG = "network"
WIRELESS_PKG = "wireless"
LOGGER = logging.getLogger(__name__)

INTERNET_APP = Bottle()
INTERNET_APP.install(JWT_PLUGIN)
INTERNET_APP.install(UCI_PLUGIN)


def validate_internet(internet):
    """ validate an internet setup """
    valid = True
    try:
        valid &= validate_option("boolean", internet["cable"])
        if internet["cable"]:
            valid &= validate_option("string", internet["interfaceName"])
        else:
            valid &= validate_option("string", internet["ssid"])
            valid &= validate_option("boolean", internet["encryption"])
            if internet["encryption"]:
                valid &= validate_option("string", internet["key"])
                valid &= 8 < len(internet["key"].encode('utf-8')) <= 32
    except KeyError:
        valid = False
    return valid


@INTERNET_APP.get('/internet')
@jwt_auth_required
def get_internet(uci):
    """Displays the current information used to connect to the internet"""
    try:
        network_uci = uci.get_package(NETWORK_PKG)
        internet = next({
            "cable": True,
            "interfaceName": network["ifname"] if "ifname" in network else ""
        } for network in network_uci if network[".type"] == "interface" and network["id"] == "wan")
        if internet["interfaceName"] != "":
            return internet
        wireless_uci = uci.get_package(WIRELESS_PKG)
        wireless_internet = next({
            "cable": False,
            "ssid": wireless["ssid"],
            "key": wireless["key"],
            "encryption": wireless["encryption"] == "psk-mixed"
        } for wireless in wireless_uci if wireless[".type"] == "wifi-iface" and wireless["network"] == "wan")
        return wireless_internet
    except UciException:
        response.status = 400
        return "Error getting internet details"


@INTERNET_APP.put('/internet')
@jwt_auth_required
def set_internet(uci):
    """Sets the information required to connect to the internet over cable or wireless"""
    try:
        updated_internet = dict(request.json)
        if not validate_internet(updated_internet):
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
        uci.persist(NETWORK_PKG)
        wireless_uci = uci.get_package(WIRELESS_PKG)
        found_sta_wireless = False
        for wireless in wireless_uci:
            if wireless[".type"] == "wifi-iface" and wireless["network"] == "wan":
                found_sta_wireless = True
                if updated_internet["cable"]:
                    uci.delete_config(WIRELESS_PKG, wireless["id"])
                else:
                    uci.set_option(WIRELESS_PKG, wireless["id"], "ssid", updated_internet["ssid"])
                    uci.set_option(WIRELESS_PKG, wireless["id"], "key",
                                   updated_internet["key"] if updated_internet["encryption"] else "none")
                    uci.set_option(WIRELESS_PKG, wireless["id"], "encryption",
                                   "psk-mixed" if updated_internet["encryption"] else "none")
        if not found_sta_wireless:
            uci.add_config(WIRELESS_PKG, {
                ".type": "wifi-iface",
                "id": "wan",
                "device": "radio0",
                "network": "wan",
                "mode": "sta",
                "ifname": "eth0.2",
                "ssid": updated_internet["ssid"],
                "encryption": "psk-mixed" if updated_internet["encryption"] else "none",
                "key": updated_internet["key"] if updated_internet["encryption"] else "none"})
        uci.persist(WIRELESS_PKG)
        run(["/etc/init.d/network", "reload"])
        return updated_internet
    except (JSONDecodeError, UciException, KeyError, TypeError):
        response.status = 400
        return "Invalid content"
