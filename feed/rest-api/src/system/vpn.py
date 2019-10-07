""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from subprocess import run
import json
from json.decoder import JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, response, request
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.uci import UciException
from plugins.plugin_uci import UCI_PLUGIN
from utils.iso import ISO_COUNTRY
from utils.validate import validate_option


LOGGER = logging.getLogger(__name__)
VPN_PKG = "vpn"

VPN_APP = Bottle()
VPN_APP.install(JWT_PLUGIN)
VPN_APP.install(UCI_PLUGIN)


def get_locations(uci):
    """helper function to get a list of VPN locations"""
    vpn_uci = uci.get_package(VPN_PKG)
    locations = {}
    for vpn in vpn_uci:
        if vpn[".type"] == "server":
            country = ISO_COUNTRY.get(vpn["country"], vpn["country"])
            if country in locations:
                if vpn["city"] in locations[country]:
                    locations[country][vpn["city"]].append(vpn["id"])
                else:
                    locations[country][vpn["city"]] = [vpn["id"]]
            else:
                locations[country] = {vpn["city"]: [vpn["id"]]}
    return locations


@VPN_APP.get('/system/vpn')
@jwt_auth_required
def get_vpn(uci):
    """gets the VPN credentials, account status and available locations"""
    try:
        username, password = ("", "")
        try:
            with open("/etc/openvpn/login.auth", "r") as vpn_credentials_file:
                username = vpn_credentials_file.readline().rstrip()
                password = vpn_credentials_file.readline().rstrip()
        except (FileNotFoundError, IOError, StopIteration):
            pass
        locations = get_locations(uci)
        for vpn in uci.get_package(VPN_PKG):
            if vpn[".type"] == "active":
                registered = vpn["registered"] if "registered" in vpn else "unknown"
                renewal = vpn["renewal"] if "renewal" in vpn else "unknown"
                expiry = vpn["expiry"] if "expiry" in vpn else "unknown"
        response.content_type = "application/json"
        return json.dumps({"vpn": {"account": {"username": username,
                                               "password": password,
                                               "registered": registered,
                                               "renewal": renewal,
                                               "expiry": expiry},
                                   "locations": locations}}, sort_keys=True)
    except UciException:
        response.status = 400
        return "Error with vpn config"


def validate_credentials(credentials):
    """ validate credentials """
    valid = True
    try:
        valid &= validate_option("string", credentials["account"]["username"])
        valid &= validate_option("string", credentials["account"]["password"])
    except KeyError:
        valid = False
    return valid


@VPN_APP.put('/system/vpn')
@jwt_auth_required
def set_vpn(uci):
    """sets the VPN credentials"""
    try:
        credentials = dict(request.json)
        if not validate_credentials(credentials):
            response.status = 400
            return "Empty or invalid content"
        try:
            with open("/etc/openvpn/login.auth", "w") as credentials_file:
                credentials_file.write(f'{credentials["account"]["username"]}\n{credentials["account"]["password"]}')
            uci.set_option(VPN_PKG, "active", "username", credentials["account"]["username"])
            uci.set_option(VPN_PKG, "active", "registered", "unknown")
            uci.set_option(VPN_PKG, "active", "renewal", "unknown")
            uci.set_option(VPN_PKG, "active", "expiry", "unknown")
            uci.persist(VPN_PKG)
            run(["/etc/init.d/openvpn", "restart"])
        except (FileNotFoundError, IOError, UciException):
            response.status = 400
            return "Error writing credentials"
        return credentials
    except (JSONDecodeError, UciException):
        response.status = 400
        return "Invalid content"
