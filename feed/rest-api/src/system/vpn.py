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
ADMIN_PKG = "admin-interface"
IPSEC_PKG = "ipsec"
VPN_PKG = "vpn"

VPN_APP = Bottle()
VPN_APP.install(JWT_PLUGIN)
VPN_APP.install(UCI_PLUGIN)


def _add_server_id_to_protocol(locations, protocol_id, server_id):
    """helper function to simplify the next function"""
    if protocol_id not in locations:
        locations[protocol_id] = []
    locations[protocol_id].append(server_id)


def get_locations_protocols(uci):
    """helper function to get a list of VPN locations and protocols"""
    vpn_uci = uci.get_package(VPN_PKG)
    locations = {}
    protocols = {}
    for vpn in vpn_uci:
        if vpn[".type"] == "server":
            country = ISO_COUNTRY.get(vpn["country"], vpn["country"])
            city = vpn["city"]
            if country not in locations:
                locations[country] = {}
            if city not in locations[country]:
                locations[country][city] = {}
            if "protocol_id" in vpn:
                for protocol in vpn["protocol_id"]:
                    _add_server_id_to_protocol(locations[country][city], protocol, vpn["id"])
            elif "filename" in vpn:
                _add_server_id_to_protocol(locations[country][city], "filename", vpn["id"])
                protocols["filename"] = {"name": "From OVPN", "vpnProtocol": "OpenVPN"}
        elif vpn[".type"] == "protocol":
            protocols[vpn["id"]] = {
                "vpnProtocol": vpn["vpn_protocol"] if "vpn_protocol" in vpn else "OpenVPN",
                "name": vpn["name"] if "name" in vpn else "OpenVPN"
            }
    return locations, protocols


def get_vpn_servers(uci):
    """gets the VPN servers names and addresses"""
    try:
        vpn_uci = uci.get_package(VPN_PKG)
        servers = {}
        for vpn in vpn_uci:
            if vpn[".type"] == "server":
                servers[vpn["id"]] = {}
                servers[vpn["id"]]["name"] = vpn["name"] if "name" in vpn else "unknown"
                if "address" in vpn:
                    servers[vpn["id"]]["address"] = vpn["address"]
        return servers
    except UciException:
        response.status = 400
        return "Error with vpn config"


def get_vpn_account(uci):
    """gets the VPN credentials and account status (helper)"""
    openvpn_username, openvpn_password = ("", "")
    registered, renewal, expiry = ("unknown", "unknown", "unknown")
    try:
        with open("/etc/openvpn/login.auth", "r") as vpn_credentials_file:
            openvpn_username = vpn_credentials_file.readline().rstrip()
            openvpn_password = vpn_credentials_file.readline().rstrip()
    except (FileNotFoundError, IOError, StopIteration):
        pass
    for vpn in uci.get_package(VPN_PKG):
        if vpn[".type"] == "active":
            registered = vpn["registered"] if "registered" in vpn else "unknown"
            renewal = vpn["renewal"] if "renewal" in vpn else "unknown"
            expiry = vpn["expiry"] if "expiry" in vpn else "unknown"
    account = {
        "openvpnUsername": openvpn_username,
        "openvpnPassword": openvpn_password,
        "registered": registered,
        "renewal": renewal,
        "expiry": expiry
    }
    if uci.get_option(ADMIN_PKG, "features", "separate_ipsec_credentials") == "true":
        try:
            account["ipsecUsername"] = uci.get_option(IPSEC_PKG, "vpn_1", "eap_identity")
            account["ipsecPassword"] = uci.get_option(IPSEC_PKG, "vpn_1", "eap_password")
        except UciException:
            account["ipsecUsername"] = ""
            account["ipsecPassword"] = ""
    return account


@VPN_APP.get('/system/vpn')
@jwt_auth_required
def get_vpn(uci):
    """gets the VPN credentials, account status and available locations"""
    try:
        locations, protocols = get_locations_protocols(uci)
        response.content_type = "application/json"
        return json.dumps({
            "vpn": {
                "account": get_vpn_account(uci),
                "locations": locations,
                "protocols": protocols,
                "servers": get_vpn_servers(uci)
            }}, sort_keys=True)
    except UciException:
        response.status = 400
        return "Error with vpn config"


def validate_credentials(credentials, uci):
    """ validate credentials """
    valid = True
    try:
        valid &= validate_option("string", credentials["account"]["openvpnUsername"])
        valid &= validate_option("string", credentials["account"]["openvpnPassword"])
        if uci.get_option(ADMIN_PKG, "features", "separate_ipsec_credentials") == "true":
            valid &= validate_option("string", credentials["account"]["ipsecUsername"])
            valid &= validate_option("string", credentials["account"]["ipsecPassword"])
    except KeyError:
        valid = False
    return valid


@VPN_APP.put('/system/vpn')
@jwt_auth_required
def set_vpn_credentials(uci):
    """sets the OpenVPN and IPSec credentials"""
    try:
        credentials = dict(request.json)
        if not validate_credentials(credentials, uci):
            response.status = 400
            return "Empty or invalid content"
        try:
            with open("/etc/openvpn/login.auth", "w") as credentials_file:
                credentials_file.write(f'{credentials["account"]["openvpnUsername"]}\n'
                                       f'{credentials["account"]["openvpnPassword"]}')
            uci.set_option(VPN_PKG, "active", "username", credentials["account"]["openvpnUsername"])
            uci.set_option(VPN_PKG, "active", "registered", "unknown")
            uci.set_option(VPN_PKG, "active", "renewal", "unknown")
            uci.set_option(VPN_PKG, "active", "expiry", "unknown")
            uci.persist(VPN_PKG)
            run(["/etc/init.d/openvpn", "restart"], check=False)
        except (FileNotFoundError, IOError, UciException):
            response.status = 400
            return "Error writing credentials"
        try:
            for net in {"vpn_1", "vpn_2", "vpn_3", "vpn_4"}:
                if uci.get_option(ADMIN_PKG, "features", "separate_ipsec_credentials") == "true":
                    uci.set_option(IPSEC_PKG, net, "eap_identity", credentials["account"]["ipsecUsername"])
                    uci.set_option(IPSEC_PKG, net, "eap_password", credentials["account"]["ipsecPassword"])
                else:
                    uci.set_option(IPSEC_PKG, net, "eap_identity", credentials["account"]["openvpnUsername"])
                    uci.set_option(IPSEC_PKG, net, "eap_password", credentials["account"]["openvpnPassword"])
            uci.persist(IPSEC_PKG)
            run(["/etc/init.d/ipsec", "restart"], check=False)
        except (FileNotFoundError, IOError, UciException):
            response.status = 400
            return "Error writing IKEv2 credentials"
        return credentials
    except (JSONDecodeError, UciException):
        response.status = 400
        return "Invalid content"
