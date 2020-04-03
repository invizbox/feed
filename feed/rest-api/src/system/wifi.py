""" Copyright 2019 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from subprocess import run
from json.decoder import JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, response, request
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.uci import UciException
from plugins.plugin_uci import UCI_PLUGIN
from utils.validate import validate_option


LOGGER = logging.getLogger(__name__)
WIRELESS_PKG = "wireless"

WIFI_APP = Bottle()
WIFI_APP.install(JWT_PLUGIN)
WIFI_APP.install(UCI_PLUGIN)


@WIFI_APP.get('/system/wifi')
@jwt_auth_required
def get_wifi(uci):
    """gets the WiFi channels currently used for 2.4GHZ and 5GHz"""
    try:
        wireless_uci = uci.get_package(WIRELESS_PKG)
        channel_24, channel_5 = ("11", "36")
        for device in wireless_uci:
            if device[".type"] == "wifi-device":
                if device["id"] == "radio0":
                    channel_24 = device["channel"]
                elif device["id"] == "radio1":
                    channel_5 = device["channel"]
        return {"channels": {"2.4GHz": int(channel_24), "5GHz": int(channel_5)}}
    except (UciException, ValueError):
        response.status = 400
        return "Error getting channel information"


def validate_wifi(wifi):
    """validate wifi settings"""
    valid = True
    try:
        valid &= validate_option("integer", wifi["channels"]["2.4GHz"])
        valid &= (1 <= wifi["channels"]["2.4GHz"] <= 14)
        valid &= validate_option("integer", wifi["channels"]["5GHz"])
        valid &= ((36 <= wifi["channels"]["5GHz"] <= 64) or (100 <= wifi["channels"]["5GHz"] <= 112)) \
                 and (wifi["channels"]["5GHz"] % 4 == 0)
    except (TypeError, KeyError):
        valid = False
    return valid


@WIFI_APP.put('/system/wifi')
@jwt_auth_required
def set_wifi(uci):
    """sets the WiFi channels used for 2.4GHz and 5GHz"""
    try:
        wifi = dict(request.json)
        if not validate_wifi(wifi):
            response.status = 400
            return "Empty or invalid content"
        try:
            current_wifi = get_wifi(uci)
            if current_wifi == "Error getting channel information":
                raise UciException()
            if current_wifi["channels"]["2.4GHz"] != wifi["channels"]["2.4GHz"] \
                    or current_wifi["channels"]["5GHz"] != wifi["channels"]["5GHz"]:
                uci.set_option(WIRELESS_PKG, "radio0", "channel", str(wifi["channels"]["2.4GHz"]))
                uci.set_option(WIRELESS_PKG, "radio1", "channel", str(wifi["channels"]["5GHz"]))
                uci.persist(WIRELESS_PKG)
            run(["/etc/init.d/network", "reload"], check=False)
        except UciException:
            response.status = 400
            return "Error writing wifi channels"
        return wifi
    except JSONDecodeError:
        response.status = 400
        return "Invalid content"
