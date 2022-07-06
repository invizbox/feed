""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from subprocess import run
from random import choice
from re import sub
import json
from json.decoder import JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, response, request
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.uci import UciException
from plugins.plugin_uci import UCI_PLUGIN
from utils.iso import ISO_COUNTRY
from utils.validate import validate_option
import networks

LOGGER = logging.getLogger(__name__)
IPSEC_PKG = "ipsec"
UPDATE_PKG = "update"
VPN_PKG = "vpn"
PROVIDERS_WITH_SEPARATE_IPSEC_CREDS = ["expressvpn", "windscribe"]
COUNTRY_TABLE = {
    "Canada East": "CA",
    "Canada West": "CA",
    "UK": "GB",
    "US Central": "US",
    "US East": "US",
    "US West": "US"
}

VPN_APP = Bottle()
VPN_APP.install(JWT_PLUGIN)
VPN_APP.install(UCI_PLUGIN)


def _add_server_id_to_protocol(locations, protocol_id, server_id):
    """Helper function to simplify the next function"""
    if protocol_id not in locations:
        locations[protocol_id] = []
    locations[protocol_id].append(server_id)


def get_plans(uci):
    """Helper function to get a list of VPN plans"""
    vpn_uci = uci.get_package(VPN_PKG)
    plans = set()
    for vpn in vpn_uci:
        if vpn[".type"] == "server" and "plan" in vpn and vpn["plan"]:
            plans.add(vpn["plan"])
    return list(sorted(plans))


def get_active_servers(uci):
    """Helper function to get a list of active servers"""
    active_config = uci.get_config(VPN_PKG, "active")
    return [option for option, _ in active_config.items() if option.startswith("vpn_")]


def get_locations_protocols(uci):
    """Helper function to get a list of VPN locations and protocols"""
    vpn_uci = uci.get_package(VPN_PKG)
    locations = {}
    protocols = {}
    for vpn in vpn_uci:
        if vpn[".type"] == "active":
            plan = vpn["plan"] if "plan" in vpn else ""
            break
    for vpn in vpn_uci:
        if vpn[".type"] == "server":
            if plan == "" or ("plan" in vpn and vpn["plan"] == plan):
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
                    protocols["filename"] = {"default": False, "name": "From OVPN", "vpnProtocol": "OpenVPN"}
        elif vpn[".type"] == "protocol":
            protocols[vpn["id"]] = {
                "vpnProtocol": vpn["vpn_protocol"] if "vpn_protocol" in vpn else "OpenVPN",
                "default": "default" in vpn and vpn["default"] == "true",
                "name": vpn["name"] if "name" in vpn else "OpenVPN"
            }
    return locations, protocols


def get_vpn_servers(uci, plan):
    """Get the VPN servers names and addresses"""
    try:
        vpn_uci = uci.get_package(VPN_PKG)
        servers = {}
        for vpn in vpn_uci:
            if vpn[".type"] == "server":
                if plan == "" or ("plan" in vpn and vpn["plan"] == plan):
                    servers[vpn["id"]] = {}
                    servers[vpn["id"]]["name"] = vpn["name"] if "name" in vpn else "unknown"
                    if "address" in vpn:
                        servers[vpn["id"]]["address"] = vpn["address"]
        return servers
    except UciException:
        response.status = 400
        return "Error with vpn config"


def get_vpn_account(uci):
    """Get the VPN credentials and account status (helper)"""
    openvpn_username, openvpn_password = ("", "")
    registered, renewal, expiry = ("unknown", "unknown", "unknown")
    try:
        openvpn_username = uci.get_option("vpn", "active", "username")
    except UciException:
        pass
    try:
        with open("/etc/openvpn/login.auth", "r", encoding="utf-8") as vpn_credentials_file:
            openvpn_password = vpn_credentials_file.readlines()[1].rstrip()
    except (IndexError, FileNotFoundError, IOError, StopIteration):
        pass
    for vpn in uci.get_package(VPN_PKG):
        if vpn[".type"] == "active":
            plan = vpn["plan"] if "plan" in vpn else ""
            registered = vpn["registered"] if "registered" in vpn else "unknown"
            renewal = vpn["renewal"] if "renewal" in vpn else "unknown"
            expiry = vpn["expiry"] if "expiry" in vpn else "unknown"
            break
    account = {
        "openvpnUsername": openvpn_username,
        "openvpnPassword": openvpn_password,
        "plan": plan,
        "registered": registered,
        "renewal": renewal,
        "expiry": expiry
    }
    try:
        provider_id = uci.get_option(VPN_PKG, "active", "provider")
        if provider_id in PROVIDERS_WITH_SEPARATE_IPSEC_CREDS:
            try:
                account["ipsecUsername"] = uci.get_option(IPSEC_PKG, "vpn_1", "eap_identity")
                if provider_id == "protonvpn":
                    account["ipsecUsername"] = sub("\\+pib$", "", account["ipsecUsername"])
                account["ipsecPassword"] = uci.get_option(IPSEC_PKG, "vpn_1", "eap_password")
            except UciException:
                account["ipsecUsername"] = ""
                account["ipsecPassword"] = ""
    except (IndexError, UciException):
        pass
    return account


@VPN_APP.get('/system/vpn')
@jwt_auth_required
def get_vpn(uci):
    """Get the VPN credentials, account status and available locations"""
    try:
        account = get_vpn_account(uci)
        locations, protocols = get_locations_protocols(uci)
        response.content_type = "application/json"
        return json.dumps({
            "vpn": {
                "account": account,
                "locations": locations,
                "protocols": protocols,
                "servers": get_vpn_servers(uci, account["plan"])
            }}, sort_keys=True)
    except UciException:
        response.status = 400
        return "Error with vpn config"


def validate_vpn(vpn_json, uci):
    """Validate VPN credentials and plan"""
    valid = True
    try:
        valid &= validate_option("string", vpn_json["account"]["openvpnUsername"])
        valid &= validate_option("string", vpn_json["account"]["openvpnPassword"])
        try:
            provider_id = uci.get_option(VPN_PKG, "active", "provider")
            if provider_id in PROVIDERS_WITH_SEPARATE_IPSEC_CREDS:
                valid &= validate_option("string", vpn_json["account"]["ipsecUsername"])
                valid &= validate_option("string", vpn_json["account"]["ipsecPassword"])
        except UciException:
            pass
        valid &= validate_option("string", vpn_json["account"]["plan"])
        plans = get_plans(uci)
        if plans:
            valid &= vpn_json["account"]["plan"] in plans
        else:
            valid &= not vpn_json["account"]["plan"]
    except KeyError:
        valid = False
    return valid


def get_similar_location(uci, country, city, new_plan):
    """Get server that is in the same city, same country, nearest city or just plan"""
    same_city, same_country, nearest, same_plan = [], [], {}, []
    nearest_cities = []
    try:
        nearest_cities = uci.get_option("vpn", "active", "nearest_cities").split(", ")
        nearest = {nearest_city: [] for nearest_city in nearest_cities}
    except UciException:
        pass
    vpn_uci = uci.get_package(VPN_PKG)
    for vpn in vpn_uci:
        if vpn[".type"] == "server" and (new_plan == "" or ("plan" in vpn and vpn["plan"] == new_plan)):
            same_plan.append(vpn["id"])
            for nearest_city in nearest_cities:
                if vpn["city"] == nearest_city:
                    nearest[nearest_city].append(vpn["id"])
            server_country = COUNTRY_TABLE[vpn["country"]] if vpn["country"] in COUNTRY_TABLE else vpn["country"]
            if country == server_country and vpn["city"] == city:
                same_city.append(vpn["id"])
            if country == server_country:
                same_country.append(vpn["id"])
    if same_city:
        return choice(same_city)
    if same_country:
        return choice(same_country)
    for nearest_city in nearest_cities:
        if nearest[nearest_city]:
            return choice(nearest[nearest_city])
    if same_plan:
        return choice(same_plan)
    return None


def update_obsolete_servers(uci, new_plan):
    """Set servers matching the users new plan"""
    restart = False
    previous_servers = {}
    for network_id in get_active_servers(uci):
        server = uci.get_option(VPN_PKG, "active", network_id)
        try:
            previous_servers[network_id] = uci.get_config(VPN_PKG, server)
        except UciException:
            previous_servers[network_id] = None
    for network_id, server in previous_servers.items():
        new_plan_servers = get_vpn_servers(uci, new_plan)
        if server and "id" in server and server["id"] not in new_plan_servers:
            network = networks.get_network(f"lan_vpn{network_id[-1]}", uci)
            if network["name"]:
                country = COUNTRY_TABLE[server["country"]] if server["country"] in COUNTRY_TABLE else server["country"]
                network["vpn"]["location"] = get_similar_location(uci, country, server["city"], new_plan)
                networks.update_network_vpn_location(uci, network["id"], network)
                restart = True
    if restart:
        networks.restart_processes(False, False, True)


@VPN_APP.put('/system/vpn')
@jwt_auth_required
def set_vpn(uci):
    """Set the VPN credentials and plan"""
    try:
        vpn_json = dict(request.json)
        if not validate_vpn(vpn_json, uci):
            response.status = 400
            return "Empty or invalid content"
        previous_plan = ""
        try:
            previous_plan = uci.get_option(VPN_PKG, "active", "plan")
        except UciException:
            pass
        if vpn_json["account"]["plan"] != previous_plan:
            try:
                update_obsolete_servers(uci, vpn_json["account"]["plan"])
                uci.set_option(VPN_PKG, "active", "plan", vpn_json["account"]["plan"])
            except UciException:
                response.status = 400
                return "Error changing plan"
        try:
            username_tag, provider_id = "", ""
            provider_id = uci.get_option(VPN_PKG, "active", "provider")
            if provider_id == "protonvpn":
                username_tag = "+pib"
        except (UciException, IndexError):
            pass
        try:
            with open("/etc/openvpn/login.auth", "w", encoding="utf-8") as credentials_file:
                credentials_file.write(f'{vpn_json["account"]["openvpnUsername"]}{username_tag}\n'
                                       f'{vpn_json["account"]["openvpnPassword"]}')
            uci.set_option(VPN_PKG, "active", "username", vpn_json["account"]["openvpnUsername"])
            uci.set_option(VPN_PKG, "active", "registered", "unknown")
            uci.set_option(VPN_PKG, "active", "renewal", "unknown")
            uci.set_option(VPN_PKG, "active", "expiry", "unknown")
            uci.persist(VPN_PKG)
            run(["/etc/init.d/openvpn", "restart"], check=False)
        except (FileNotFoundError, IOError, UciException):
            response.status = 400
            return "Error writing credentials"
        try:
            for network_id in get_active_servers(uci):
                if provider_id in PROVIDERS_WITH_SEPARATE_IPSEC_CREDS:
                    uci.set_option(IPSEC_PKG, network_id, "eap_identity",
                                   vpn_json["account"]["ipsecUsername"]+username_tag)
                    uci.set_option(IPSEC_PKG, network_id, "eap_password", vpn_json["account"]["ipsecPassword"])
                else:
                    uci.set_option(IPSEC_PKG, network_id, "eap_identity",
                                   vpn_json["account"]["openvpnUsername"]+username_tag)
                    uci.set_option(IPSEC_PKG, network_id, "eap_password", vpn_json["account"]["openvpnPassword"])
            uci.persist(IPSEC_PKG)
            run(["/etc/init.d/ipsec", "restart"], check=False)
        except (FileNotFoundError, IOError, UciException):
            response.status = 400
            return "Error writing IKEv2 credentials"
        return vpn_json
    except (JSONDecodeError, UciException):
        response.status = 400
        return "Invalid content"
