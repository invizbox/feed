""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from subprocess import run
from os import system
from json.decoder import JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, request, response
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.plugin_uci import UCI_PLUGIN, UCI_ROM_PLUGIN
from plugins.uci import UciException
from utils.validate import validate_option
from admin_interface import hold_ping
from system.vpn import get_locations
import profiles

ADMIN_PKG = "admin-interface"
DHCP_PKG = "dhcp"
NETWORK_PKG = "network"
OPENVPN_PKG = "openvpn"
VPN_PKG = "vpn"
WIRELESS_PKG = "wireless"
INTERFACES = {"LAN": "eth0.1", "1": "eth1.1", "2": "eth1.2", "3": "eth1.3", "4": "eth1.4"}
PORTS = {"eth0.1": "LAN", "eth1.1": "1", "eth1.2": "2", "eth1.3": "3", "eth1.4": "4"}
LOGGER = logging.getLogger(__name__)

NETWORKS_APP = Bottle()
NETWORKS_APP.install(JWT_PLUGIN)
NETWORKS_APP.install(UCI_PLUGIN)
NETWORKS_APP.install(UCI_ROM_PLUGIN)
NETWORKS_APP.wifi_password = ''


def validate_location(new_location, locations):
    """helper function to check if a location is in the available ones"""
    for country in locations.values():
        for city in country.values():
            if new_location in city:
                return True
    return False


def validate_network(network, uci):
    """ validate a network """
    valid = True
    try:
        valid &= validate_option("string", network["id"])
        valid &= validate_option("string", network["name"])
        valid &= validate_option("boolean", network["enabled"])
        valid &= network["type"] in {"clear", "vpn", "tor", "local"}
        valid &= validate_option("string", network["profileId"])
        if network["profileId"]:
            all_profiles = profiles.get_profiles()
            try:
                next(profile for profile in all_profiles["profiles"] if profile["id"] == network["profileId"])
            except StopIteration:
                valid = False
        valid &= validate_option("string_list", network["ports"])
        valid &= validate_option("network", [network["dhcp"]["ipaddr"], network["dhcp"]["netmask"]])
        valid &= validate_option("boolean", network["wifi"]["enabled24Ghz"])
        valid &= validate_option("boolean", network["wifi"]["enabled5Ghz"])
        valid &= validate_option("string", network["wifi"]["ssid"])
        valid &= 1 <= len(network["wifi"]["ssid"].encode('utf-8')) <= 27
        valid &= validate_option("boolean", network["wifi"]["encryption"])
        if network["wifi"]["encryption"]:
            valid &= validate_option("string", network["wifi"]["key"])
            valid &= 8 <= len(network["wifi"]["key"].encode('utf-8')) <= 63
        valid &= validate_option("boolean", network["wifi"]["isolate"])
        valid &= validate_option("boolean", network["wifi"]["hidden"])
        if network["type"] == "vpn":
            new_location = network["vpn"]["location"]
            valid &= validate_option("string", new_location)

            locations = get_locations(uci)
            valid &= validate_location(new_location, locations)
    except KeyError:
        valid = False
    return valid


def get_networks_wireless(uci, networks):
    """ add wireless info to networks """
    wireless_uci = uci.get_package(WIRELESS_PKG)
    for wireless in wireless_uci:
        if wireless[".type"] == "wifi-iface" and "network" in wireless and "disabled" in wireless:
            for network in networks:
                if network["id"] == wireless["network"] and wireless["id"] != "lan_5GHz":
                    network["wifi"]["ssid"] = wireless["ssid"] if "ssid" in wireless else ""
                    network["wifi"]["encryption"] = wireless["encryption"] != "none"
                    if network["wifi"]["encryption"]:
                        network["wifi"]["key"] = wireless["key"] if "key" in wireless else ""
                    else:
                        network['wifi']['key'] = None
                    network["wifi"]["isolate"] = wireless["isolate"] == "1" if "isolate" in wireless else False
                    network["wifi"]["hidden"] = wireless["hidden"] == "1" if "hidden" in wireless else False


def get_networks_openvpn(uci, networks):
    """ add openvpn info to networks """
    openvpn_uci = uci.get_package(OPENVPN_PKG)
    for openvpn in openvpn_uci:
        if openvpn[".type"] == "openvpn" and "enabled" in openvpn:
            for network in networks:
                if network["id"] == "lan_vpn" + openvpn["id"][-1]:
                    network["type"] = "vpn"
                    network["vpn"] = {}
                    network["enabled"] &= openvpn["enabled"] == "1"


def get_networks_vpn_location(uci, networks):
    """ add openvpn info to networks """
    vpn_uci = uci.get_package(VPN_PKG)
    for network in networks:
        if network["type"] == "vpn":
            try:
                entry_name = "vpn_{}".format(network["id"][-1])
                vpn_entry = next(vpn[entry_name] for vpn in vpn_uci if vpn[".type"] == "active" and entry_name in vpn)
            except StopIteration:
                vpn_entry = "unknown"
            network["vpn"]["location"] = vpn_entry


def get_networks_dhcp(uci, networks):
    """ add dhcp info to networks """
    dhcp_uci = uci.get_package(DHCP_PKG)
    for dhcp in dhcp_uci:
        if dhcp[".type"] in {"dhcp", "dnsmasq"} and "disabled" in dhcp:
            for network in networks:
                if network["id"] == dhcp["interface"]:
                    network["enabled"] &= dhcp["disabled"] != "1"


def get_networks_admin(uci, networks):
    """ add admin-interface info to networks """
    admin_uci = uci.get_package(ADMIN_PKG)
    for admin in admin_uci:
        if admin[".type"] == "network":
            for network in networks:
                if network["id"] == admin["id"]:
                    network["wifi"]["enabled24Ghz"] = admin["enabled_2_4ghz"] == "true"
                    network["wifi"]["enabled5Ghz"] = admin["enabled_5ghz"] == "true"
                    network["profileId"] = admin["profile_id"]
                    network["name"] = admin["name"]
                    break


def get_networks(uci):
    """" helper function to get all information related to networks from UCI """
    network_uci = uci.get_package(NETWORK_PKG)
    networks = [
        {
            "id": network["id"],
            "name": network["id"],
            "enabled": True,
            "type": "tor" if network["id"] == "lan_tor" else "local" if network["id"] == "lan_local" else "clear",
            "ports": [PORTS[ifname] for ifname in network["ifname"].split(" ")] if "ifname" in network else [],
            "profileId": None,
            "dhcp": {
                "ipaddr": network["ipaddr"],
                "netmask": network["netmask"]
            },
            "wifi": {"enabled24Ghz": False,
                     "enabled5Ghz": False}
        }
        for index, network in enumerate(network_uci)
        if network[".type"] == "interface" and network["id"].startswith("lan_")
    ]
    get_networks_admin(uci, networks)
    get_networks_wireless(uci, networks)
    get_networks_openvpn(uci, networks)
    get_networks_vpn_location(uci, networks)
    get_networks_dhcp(uci, networks)
    return networks


@NETWORKS_APP.get('/networks')
@jwt_auth_required
def list_networks(uci):
    """ list networks """
    try:
        return {"networks": get_networks(uci)}
    except UciException:
        response.status = 400
        return "Error with networks"


@NETWORKS_APP.get('/networks/<network_id>')
@jwt_auth_required
def get_network(network_id, uci):
    """ list a specific network """
    try:
        networks = get_networks(uci)
        network = next(network for network in networks if network["id"] == network_id)
        return network
    except (StopIteration, UciException):
        response.status = 404
        return "Invalid id"


def update_network_network(uci, network_id, updated_network):
    """ update the network part of a specific network """
    network_uci = uci.get_package(NETWORK_PKG)
    for network in network_uci:
        if network[".type"] == "interface" and network["id"] == network_id:
            new_if_list = " ".join([INTERFACES[port] for port in updated_network["ports"]])
            if new_if_list:
                uci.set_option(NETWORK_PKG, network["id"], "ifname", new_if_list)
            else:
                try:
                    uci.delete_option(NETWORK_PKG, network["id"], "ifname")
                except UciException:
                    pass
        elif network[".type"] == "interface" and "type" in network and network["type"] == "bridge" \
                and "ifname" in network:
            old_if_list = network["ifname"].split(" ")
            new_if_list = [ifname for ifname in old_if_list if PORTS[ifname] not in updated_network["ports"]]
            if new_if_list != old_if_list:
                if new_if_list:
                    uci.set_option(NETWORK_PKG, network["id"], "ifname", " ".join([INTERFACES[port]
                                                                                   for port in new_if_list]))
                elif old_if_list:
                    uci.delete_option(NETWORK_PKG, network["id"], "ifname")
    uci.persist(NETWORK_PKG)


def update_network_wireless(uci, network_id, upd_network):
    """ update the wireless part of a specific network """
    wireless_uci = uci.get_package(WIRELESS_PKG)
    for wireless in wireless_uci:
        if wireless[".type"] == "wifi-iface" and "network" in wireless and "disabled" in wireless:
            if wireless["id"] == "lan_5GHz":
                if upd_network["wifi"]["enabled5Ghz"] or wireless["network"] == network_id:
                    uci.set_option(WIRELESS_PKG, wireless["id"], "disabled",
                                   "0" if upd_network["wifi"]["enabled5Ghz"] and upd_network["enabled"] else "1")
                    uci.set_option(WIRELESS_PKG, wireless["id"], "ssid", f'{upd_network["wifi"]["ssid"]} 5GHz')
                    uci.set_option(WIRELESS_PKG, wireless["id"], "network", upd_network["id"])
                    uci.set_option(WIRELESS_PKG, wireless["id"], "encryption",
                                   "psk2+aes" if upd_network["wifi"]["encryption"] else "none")
                    if upd_network["wifi"]["encryption"]:
                        uci.set_option(WIRELESS_PKG, wireless["id"], "key", upd_network["wifi"]["key"])
                    elif "key" in wireless:
                        uci.delete_option(WIRELESS_PKG, wireless["id"], "key")
                    uci.set_option(WIRELESS_PKG, wireless["id"], "isolate",
                                   "1" if upd_network["wifi"]["isolate"] else "0")
                    uci.set_option(WIRELESS_PKG, wireless["id"], "hidden",
                                   "1" if upd_network["wifi"]["hidden"] else "0")
            elif wireless["network"] == network_id:
                uci.set_option(WIRELESS_PKG, wireless["id"], "disabled",
                               "0" if upd_network["wifi"]["enabled24Ghz"] and upd_network["enabled"] else "1")
                uci.set_option(WIRELESS_PKG, wireless["id"], "ssid", upd_network["wifi"]["ssid"])
                uci.set_option(WIRELESS_PKG, wireless["id"], "encryption",
                               "psk2+aes" if upd_network["wifi"]["encryption"] else "none")
                if upd_network["wifi"]["encryption"]:
                    uci.set_option(WIRELESS_PKG, wireless["id"], "key", upd_network["wifi"]["key"])
                elif "key" in wireless:
                    uci.delete_option(WIRELESS_PKG, wireless["id"], "key")
                uci.set_option(WIRELESS_PKG, wireless["id"], "isolate", "1" if upd_network["wifi"]["isolate"] else "0")
                uci.set_option(WIRELESS_PKG, wireless["id"], "hidden", "1" if upd_network["wifi"]["hidden"] else "0")
    uci.persist(WIRELESS_PKG)


def update_network_openvpn(uci, network_id, updated_network):
    """ update the openvpn part of a specific network """
    openvpn_uci = uci.get_package(OPENVPN_PKG)
    for openvpn in openvpn_uci:
        if openvpn[".type"] == "openvpn" and "enabled" in openvpn and network_id == "lan_vpn" + openvpn["id"][-1]:
            uci.set_option(OPENVPN_PKG, openvpn["id"], "enabled", "1" if updated_network["enabled"] else "0")
            break
    uci.persist(OPENVPN_PKG)


def update_network_vpn_location(uci, network_id, updated_network):
    """ update the vpn part of a specific network """
    vpn_uci = uci.get_package(VPN_PKG)
    entry_name = f"vpn_{network_id[-1]}"
    for vpn in vpn_uci:
        if vpn[".type"] == "active" and entry_name in vpn:
            if vpn[entry_name] == updated_network["vpn"]["location"]:
                LOGGER.info("current VPN config is already in use, no change")
                break
            try:
                location_conf = uci.get_config(VPN_PKG, updated_network["vpn"]["location"])
                uci.set_option(VPN_PKG, "active", entry_name, updated_network["vpn"]["location"])
                uci.persist(VPN_PKG)
                with open("/tmp/vpn_location", "w") as out_file:
                    if "template" in location_conf:
                        run(["sed", f's/@SERVER_ADDRESS@/{location_conf["address"]}/; s/@TUN@/tun{network_id[-1]}/',
                             f'{location_conf["template"]}'], stdout=out_file)
                    elif "filename" in location_conf:
                        run(["sed", f's/@TUN@/tun{network_id[-1]}/', f'{location_conf["filename"]}'], stdout=out_file)
                if system(f"cp /tmp/vpn_location /etc/openvpn/openvpn_{network_id[-1]}.conf") == 0:
                    LOGGER.info('%s is now the active VPN location for %s', updated_network["vpn"]["location"],
                                entry_name)
                else:
                    LOGGER.info('error setting %s as the VPN location for %s', updated_network["vpn"]["location"],
                                entry_name)
            except UciException:
                LOGGER.info('No VPN location named %s', updated_network["vpn"]["location"])
            break


def update_network_dhcp(uci, network_id, updated_network):
    """ update the dhcp part of a specific network """
    dhcp_uci = uci.get_package(DHCP_PKG)
    for dhcp in dhcp_uci:
        if dhcp[".type"] == "dhcp" and "disabled" in dhcp and dhcp["interface"] == network_id:
            uci.set_option(DHCP_PKG, dhcp["id"], "disabled", "0" if updated_network["enabled"] else "1")
        if dhcp[".type"] == "dnsmasq" and "disabled" in dhcp and network_id in dhcp["interface"]:
            disable_dnmasq = False
            for interface in dhcp["interface"]:
                try:
                    if network_id == interface:  # network being currently modified
                        dhcp_enabled = updated_network["enabled"]
                    else:
                        dhcp_enabled = next(temp["disabled"] for temp in dhcp_uci if temp[".type"] == "dhcp"
                                            and temp["interface"] == interface) == "0"
                    disable_dnmasq |= dhcp_enabled
                except StopIteration:
                    pass
            uci.set_option(DHCP_PKG, dhcp["id"], "disabled", "0" if disable_dnmasq else "1")
    uci.persist(DHCP_PKG)


def update_network_admin(uci, network_id, updated_network):
    """ update the admin-interface part of a specific network """
    admin_uci = uci.get_package(ADMIN_PKG)
    for admin in admin_uci:
        if admin[".type"] == "network":
            if admin["id"] == network_id:
                uci.set_option(ADMIN_PKG, admin["id"], "profile_id", updated_network["profileId"])
                uci.set_option(ADMIN_PKG, admin["id"], "name", updated_network["name"])
                uci.set_option(ADMIN_PKG, admin["id"], "enabled_2_4ghz",
                               "true" if updated_network["wifi"]["enabled24Ghz"] else "false")
                uci.set_option(ADMIN_PKG, admin["id"], "enabled_5ghz",
                               "true" if updated_network["wifi"]["enabled5Ghz"] else "false")
            elif updated_network["wifi"]["enabled5Ghz"] and admin["enabled_5ghz"] == "true":
                uci.set_option(ADMIN_PKG, admin["id"], "enabled_5ghz", "false")
    uci.persist(ADMIN_PKG)


def update_network_profile(uci, network_id, current_profile_id, new_profile_id):
    """ update the services to match the new profile associated with a specific network """
    all_profiles = profiles.get_profiles()
    try:
        current_profile = next(profile for profile in all_profiles["profiles"] if profile["id"] == current_profile_id)
    except StopIteration:
        current_profile = profiles.ALL_OFF_PROFILE
    try:
        new_profile = next(profile for profile in all_profiles["profiles"] if profile["id"] == new_profile_id)
    except StopIteration:
        new_profile = profiles.ALL_OFF_PROFILE
    profiles.update_profile_network(uci, network_id, current_profile, new_profile)


def restart_processes(restart_dnsmasq, restart_network, restart_openvpn):
    """ helper function to restart processes """
    with hold_ping():
        if restart_dnsmasq:
            run(["/etc/init.d/dnsmasq", "reload"])
        if restart_network:
            run(["/etc/init.d/network", "reload"])
        if restart_openvpn:
            run(["/etc/init.d/openvpn", "restart"])


def do_update_network(network, updated_network, uci):
    """helper function to update a network and restart what is necessary"""
    restart_network, restart_openvpn, restart_dnsmasq = (False, False, False)
    if network["ports"] != updated_network["ports"]:
        network["ports"] = updated_network["ports"]
        update_network_network(uci, network["id"], updated_network)
        restart_network = True
    if network["wifi"] != updated_network["wifi"] or network["enabled"] != updated_network["enabled"]:
        network["wifi"]["ssid"] = updated_network["wifi"]["ssid"]
        network["wifi"]["encryption"] = updated_network["wifi"]["encryption"]
        if "key" in network["wifi"]:
            if "key" in updated_network["wifi"]:
                network["wifi"]["key"] = updated_network["wifi"]["key"]
            else:
                del network["wifi"]["key"]
        else:
            if "key" in updated_network["wifi"]:
                network["wifi"]["key"] = updated_network["wifi"]["key"]
        network["wifi"]["isolate"] = updated_network["wifi"]["isolate"]
        network["wifi"]["hidden"] = updated_network["wifi"]["hidden"]
        update_network_wireless(uci, network["id"], updated_network)
        restart_network = True
    if network["type"] == "vpn" and (network["vpn"] != updated_network["vpn"]
                                     or network["enabled"] != updated_network["enabled"]):
        network["vpn"] = updated_network["vpn"]
        update_network_openvpn(uci, network["id"], updated_network)
        update_network_vpn_location(uci, network["id"], updated_network)
        restart_openvpn = True
    if network["dhcp"] != updated_network["dhcp"] or network["enabled"] != updated_network["enabled"]:
        network["dhcp"] = updated_network["dhcp"]
        update_network_dhcp(uci, network["id"], updated_network)
        restart_dnsmasq = True
    if network["profileId"] != updated_network["profileId"]:
        update_network_profile(uci, network["id"], network["profileId"], updated_network["profileId"])
    if network["name"] != updated_network["name"] or network["profileId"] != updated_network["profileId"] \
            or network["wifi"]["enabled24Ghz"] != updated_network["wifi"]["enabled24Ghz"] \
            or network["wifi"]["enabled5Ghz"] != updated_network["wifi"]["enabled5Ghz"]:
        network["name"] = updated_network["name"]
        network["profileId"] = updated_network["profileId"]
        network["wifi"]["enabled24Ghz"] = updated_network["wifi"]["enabled24Ghz"]
        network["wifi"]["enabled5Ghz"] = updated_network["wifi"]["enabled5Ghz"]
        update_network_admin(uci, network["id"], updated_network)
    network["enabled"] = updated_network["enabled"]
    restart_processes(restart_dnsmasq, restart_network, restart_openvpn)
    return network


def connectivity_check(networks, network, update=True):
    """ helper function to check if we would have connectivity left after a network change """
    result = False
    for net in networks:
        if net["id"] == network["id"]:
            if update:
                result |= (network["enabled"] and (network["wifi"]["enabled24Ghz"] or network["wifi"]["enabled5Ghz"]
                                                   or len(network["ports"])))
        else:
            result |= (net["enabled"]
                       and (net["wifi"]["enabled24Ghz"] or net["wifi"]["enabled5Ghz"] or len(net["ports"])))
        if result:
            break
    return result


@NETWORKS_APP.put('/networks/<network_id>')
@jwt_auth_required
def update_network(network_id, uci):
    """ update a specific network """
    LOGGER.debug("update_network() called")
    try:
        networks = get_networks(uci)
        network = next(network for network in networks
                       if network["id"] == network_id and network["id"].startswith("lan_"))
    except (StopIteration, UciException):
        response.status = 404
        return "Invalid id"
    try:
        updated_network = dict(request.json)
        if not validate_network(updated_network, uci):
            response.status = 400
            return "Empty or invalid fields"
        if not connectivity_check(networks, updated_network):
            response.status = 400
            return "Not updating as no connectivity left on this or other networks"
        return do_update_network(network, updated_network, uci)
    except (JSONDecodeError, UciException, KeyError, TypeError):
        response.status = 400
        return "Invalid content"


@NETWORKS_APP.delete('/networks/<network_id>')
@jwt_auth_required
def delete_network(network_id, uci, uci_rom):
    """ delete a specific network """
    LOGGER.debug("delete_network() called")
    if not NETWORKS_APP.wifi_password:
        with open("/private/wifi_password.txt", "r") as password_file:
            NETWORKS_APP.wifi_password = password_file.readline().rstrip()
    try:
        networks = get_networks(uci)
        network = next(network for network in networks
                       if network["id"] == network_id and network["id"].startswith("lan_"))
    except (StopIteration, UciException):
        response.status = 404
        return "Invalid id"
    if not connectivity_check(networks, network, False):
        response.status = 400
        return "Not deleting as no connectivity left on other networks"
    try:
        deleted_network = get_network(network_id if network_id != "lan_vpn1" else "lan_vpn2", uci_rom)
        deleted_network["id"] = network_id
        deleted_network["wifi"]["key"] = NETWORKS_APP.wifi_password
        do_update_network(network, deleted_network, uci)
    except (UciException, KeyError, TypeError):
        pass
    response.status = 204
    return ""
