""" Copyright 2019 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from time import sleep
from threading import Thread, Lock
from subprocess import run
from uuid import uuid4
from os import system
from json import dump, load, JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, request, response
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.plugin_uci import UCI_PLUGIN
from utils.validate import validate_option
from system.blacklists import get_blacklists
import devices
import networks


ADMIN_PKG = "admin-interface"
BLACKLISTS_PKG = "blacklists"
FIREWALL_PKG = "firewall"
SSH_PKG = "dropbear"
ALL_OFF_PROFILE = {"ssh": {"enabled": False},
                   "deviceBlocking": {
                       "enabled": False,
                       "deviceRules": {}
                   },
                   "siteBlocking": {
                       "enabled": False,
                       "blacklistIds": [],
                       "sites": []
                   }}
LOGGER = logging.getLogger(__name__)

PROFILES_APP = Bottle()
PROFILES_APP.install(JWT_PLUGIN)
PROFILES_APP.install(UCI_PLUGIN)
PROFILES_APP.file = "/etc/profiles.json"
PROFILES_APP.profiles = None
# setting up the monitoring of DNS blacklists updates
PROFILES_APP.lists_rebuild_flag = False
PROFILES_APP.lock = Lock()


def validate_profile(updated_profile, uci):
    """validate the JSON structure of an updated profile"""
    valid = True
    try:
        valid &= validate_option("string", updated_profile["name"])
        valid &= validate_option("string", updated_profile["type"])
        valid &= updated_profile["type"] in ["standard", "parental"]
        valid &= isinstance(updated_profile["ssh"], dict)
        valid &= validate_option("boolean", updated_profile["ssh"]["enabled"])
        valid &= isinstance(updated_profile["deviceBlocking"], dict)
        valid &= validate_option("boolean", updated_profile["deviceBlocking"]["enabled"])
        all_devices = devices.get_devices(uci)
        for device_id, rules in updated_profile["deviceBlocking"]["deviceRules"].items():
            try:
                next(device for device in all_devices if device["id"] == device_id)
            except StopIteration:
                valid = False
            for rule in rules:
                if "startTime" in rule or "stopTime" in rule:
                    valid &= validate_option("time", rule["startTime"])
                    valid &= validate_option("time", rule["stopTime"])
                if "days" in rule:
                    valid &= validate_option("day_list", rule["days"])
        valid &= isinstance(updated_profile["siteBlocking"], dict)
        valid &= validate_option("boolean", updated_profile["siteBlocking"]["enabled"])
        valid &= validate_option("string_list", updated_profile["siteBlocking"]["blacklistIds"])
        blacklists = get_blacklists(uci)["blacklists"]
        for blacklist_id in updated_profile["siteBlocking"]["blacklistIds"]:
            try:
                next(blacklist for blacklist in blacklists if blacklist["id"] == blacklist_id)
            except StopIteration:
                valid = False
        valid &= validate_option("string_list", updated_profile["siteBlocking"]["sites"])
    except KeyError:
        valid = False
    return valid


def persist_profiles():
    """ persiste the profiles to file """
    try:
        with open(PROFILES_APP.file, "w") as profiles_file:
            try:
                dump(PROFILES_APP.profiles, profiles_file)
            except (IOError, JSONDecodeError):
                LOGGER.error("Invalid Profiles JSON or IOError", exc_info=1)
    except FileNotFoundError:
        LOGGER.error("Couldn't write to /etc/profiles.json", exc_info=1)


@PROFILES_APP.get('/profiles')
@jwt_auth_required
def get_profiles():
    """ list the profiles """
    if not PROFILES_APP.profiles:
        try:
            with open(PROFILES_APP.file, "r") as profiles_file:
                PROFILES_APP.profiles = load(profiles_file)
        except (FileNotFoundError, IOError, JSONDecodeError):
            PROFILES_APP.profiles = {"profiles": []}
    return PROFILES_APP.profiles


@PROFILES_APP.get('/profiles/<profile_id>')
@jwt_auth_required
def get_profile(profile_id):
    """ list the profiles """
    try:
        profiles = get_profiles()
        profile = next(profile for profile in profiles["profiles"] if profile["id"] == profile_id)
        return profile
    except StopIteration:
        response.status = 404
        return "Invalid id"


@PROFILES_APP.post('/profiles')
@jwt_auth_required
def create_profile(uci):
    """ creates a new profile """
    try:
        profile = dict(request.json)
        if not validate_profile(profile, uci):
            response.status = 400
            return "Empty or invalid content"
        profile["siteBlocking"]["sites"] = sorted(set(profile["siteBlocking"]["sites"]))
        new_profile = {
            "id": uuid4().hex,
            "name": profile["name"],
            "type": profile["type"],
            "ssh": profile["ssh"],
            "deviceBlocking": profile["deviceBlocking"],
            "siteBlocking": profile["siteBlocking"]
        }
        PROFILES_APP.profiles["profiles"].append(new_profile)
        persist_profiles()
        response.status = 201
        return new_profile
    except JSONDecodeError:
        response.status = 400
        return "Invalid content"


@PROFILES_APP.delete('/profiles/<profile_id>')
@jwt_auth_required
def delete_profile(profile_id, uci):
    """ delete a specific profile """
    profiles = get_profiles()
    try:
        profile = next(profile for profile in profiles["profiles"] if profile["id"] == profile_id)
        associated_networks = [network["id"] for network in networks.get_networks(uci)
                               if network["profileId"] == profile["id"]]
        for network_id in associated_networks:
            update_profile_network(uci, network_id, profile, ALL_OFF_PROFILE)
            uci.set_option(ADMIN_PKG, network_id, "profile_id", "")
        uci.persist(ADMIN_PKG)
        PROFILES_APP.profiles["profiles"].remove(profile)
        persist_profiles()
        response.status = 204
        return ""
    except StopIteration:
        response.status = 404
        return "Invalid Profile ID"


def create_blocking_firewall(uci, network_id, mac_address, rule):
    """helper function to create all firewall entries linked to a device"""
    firewall_uci = uci.get_package(FIREWALL_PKG)
    zone = next(zone for zone in firewall_uci if zone[".type"] == "zone" and zone["network"] == network_id)
    new_rule = {".type": "rule",
                "id": uuid4().hex,
                "enabled": "1",
                "src": zone["name"],
                "dest": "*",
                "src_mac": mac_address,
                "target": "REJECT"}
    if "startTime" in rule and "stopTime" in rule:
        new_rule["start_time"] = rule["startTime"]
        new_rule["stop_time"] = rule["stopTime"]
    if "days" in rule:
        new_rule["weekdays"] = " ".join(rule["days"])
    uci.add_config(FIREWALL_PKG, new_rule)


def rebuild_site_blocking(uci, network_id, profile):
    """ helper function to rebuild the Site Blocking for a specific network """
    with PROFILES_APP.lock:
        if profile["siteBlocking"]["enabled"]:
            user_list_file = f"/etc/dns_blacklist/{network_id}.blacklist"
            try:
                with open(user_list_file, "w") as file:
                    if profile["siteBlocking"]["sites"]:
                        separator = '/\nserver=/'
                        file.write(f"server=/{separator.join(profile['siteBlocking']['sites'])}/\n")
            except (FileNotFoundError, IOError):
                LOGGER.warning("Issue writing blacklist to /etc/dns_blacklist/%s.blacklist", network_id, exc_info=True)
            file_list = []
            for blacklist_id in profile['siteBlocking']['blacklistIds']:
                try:
                    blacklist_filename = next(blacklist["file"] for blacklist in uci.get_package(BLACKLISTS_PKG)
                                              if blacklist[".type"] == "blacklist" and blacklist["id"] == blacklist_id)
                    file_list.append(blacklist_filename)
                except StopIteration:
                    LOGGER.warning("Issue finding the filename for a blacklist", exc_info=True)
            file_list.append(user_list_file)
            system(f"cat {' '.join(file_list)} > /etc/dns_blacklist/{network_id}.overall")
        else:
            system(f"echo > /etc/dns_blacklist/{network_id}.overall")
        run(["killall", "-HUP", "dnsmasq"])


def update_profile_network(uci, network_id, current_profile, new_profile):
    """ helper function which will change from the current profile to the new profile for a specific network """
    if new_profile["ssh"] != current_profile["ssh"]:
        uci.set_option(SSH_PKG, network_id, "enable", "1" if new_profile["ssh"]["enabled"] else "0")
        uci.persist(SSH_PKG)
        run(["/etc/init.d/dropbear", "reload"])
    if new_profile["deviceBlocking"] != current_profile["deviceBlocking"]:
        for rule in uci.get_package(FIREWALL_PKG):
            if ".type" in rule and rule[".type"] == "rule" and "id" in rule and rule["id"]:
                if "src" in rule and rule["src"] == network_id:
                    uci.delete_config(FIREWALL_PKG, rule["id"])
        if new_profile["deviceBlocking"]["enabled"]:
            all_devices = devices.get_devices(uci)
            for device_id, rules in new_profile["deviceBlocking"]["deviceRules"].items():
                device = next(device for device in all_devices if device["id"] == device_id)
                for rule in rules:
                    create_blocking_firewall(uci, network_id, device["macAddress"], rule)
        uci.persist(FIREWALL_PKG)
        run(["/etc/init.d/firewall", "reload"])
    if new_profile["siteBlocking"] != current_profile["siteBlocking"]:
        rebuild_site_blocking(uci, network_id, new_profile)


@PROFILES_APP.put('/profiles/<profile_id>')
@jwt_auth_required
def update_profile(profile_id, uci):
    """ update a specific profile """
    try:
        profiles = get_profiles()
        profile = next(profile for profile in profiles["profiles"] if profile["id"] == profile_id)
        updated_profile = dict(request.json)
        if not validate_profile(updated_profile, uci):
            response.status = 400
            return "Empty or invalid content"
        associated_networks = [network["id"] for network in networks.get_networks(uci)
                               if network["profileId"] == profile_id]
        for network_id in associated_networks:
            update_profile_network(uci, network_id, profile, updated_profile)
        profile["name"] = updated_profile["name"]
        profile["type"] = updated_profile["type"]
        profile["ssh"] = updated_profile["ssh"]
        profile["deviceBlocking"] = updated_profile["deviceBlocking"]
        profile["siteBlocking"] = updated_profile["siteBlocking"]
        profile["siteBlocking"]["sites"] = sorted(set(updated_profile["siteBlocking"]["sites"]))
        persist_profiles()
        return profile
    except StopIteration:
        response.status = 404
        return "Invalid id"
    except (JSONDecodeError, KeyError, TypeError):
        response.status = 400
        return "Invalid content"


def delete_device_from_profiles(device_id):
    """ helper function to delete all references to a device in profiles"""
    for profile in get_profiles()["profiles"]:
        try:
            del profile["deviceBlocking"]["deviceRules"][device_id]
        except KeyError:
            pass
    persist_profiles()


def aggregate_loop(uci):
    """loop to check if the flag to update DNS lists is raised and do it if so"""
    while True:
        sleep(10)
        if PROFILES_APP.lists_rebuild_flag:
            PROFILES_APP.lists_rebuild_flag = False
            admin_uci = uci.get_package(ADMIN_PKG)
            for network in admin_uci:
                if network[".type"] == "network" and network["id"] != "lan_local" and network["profile_id"]:
                    rebuild_site_blocking(uci, network["id"], get_profile(network["profile_id"]))


PROFILES_APP.aggregate_thread = Thread(target=aggregate_loop, args=(UCI_PLUGIN.uci,), daemon=True)
