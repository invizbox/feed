""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from os import path, getenv
from subprocess import run, PIPE, CalledProcessError
from json.decoder import JSONDecodeError
from contextlib import contextmanager
from bottle_jwt import jwt_auth_required
from bottle import Bottle, request, response
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.plugin_uci import UCI_PLUGIN
from plugins.uci import UciException
from utils.validate import validate_option
from system import vpn


ADMIN_PKG = "admin-interface"
UPDATE_PKG = "update"
VPN_PKG = "vpn"
LOGGER = logging.getLogger(__name__)

ADMIN_INTERFACE_APP = Bottle()
ADMIN_INTERFACE_APP.install(JWT_PLUGIN)
ADMIN_INTERFACE_APP.install(UCI_PLUGIN)
ADMIN_INTERFACE_APP.model = getenv("DEVICE_PRODUCT", "InvizBox 2")
ADMIN_INTERFACE_APP.ping_ready = True
PROVIDER_NAMES = {
    "expressvpn": "ExpressVPN",
    "invizbox": "InvizBox",
    "ipvanish": "IPVanish",
    "myexpatnetwork": "StreamVPN",
    "nordvpn": "NordVPN",
    "pia": "PIA",
    "protonvpn": "ProtonVPN",
    "surfshark": "Surfshark",
    "vanishedvpn": "VanishedVPN",
    "vpncity": "VPNCity",
    "windscribe": "Windscribe",
}


@contextmanager
def hold_ping():
    """Context manager function to fail ping when the device is not ready for API calls"""
    ADMIN_INTERFACE_APP.ping_ready = False
    yield
    ADMIN_INTERFACE_APP.ping_ready = True


def get_provider_name(provider_id):
    """Get the display name for the vpn provider"""
    try:
        provider_name = PROVIDER_NAMES[provider_id]
    except KeyError:
        provider_name = "unknown"
    return provider_name


def validate_ftux(ftux):
    """Validate the ftux object"""
    valid = True
    try:
        valid &= validate_option("boolean", ftux["devices"])
        valid &= validate_option("boolean", ftux["home"])
        valid &= validate_option("boolean", ftux["networks"])
        valid &= validate_option("boolean", ftux["profiles"])
        valid &= validate_option("boolean", ftux["support"])
        valid &= validate_option("boolean", ftux["system"])
    except KeyError:
        valid = False
    return valid


def validate_onboarding(onboarding):
    """Validate the onboarding object"""
    valid = True
    try:
        valid &= validate_option("boolean", onboarding["onboarding"]["needed"])
    except (KeyError, TypeError):
        valid = False
    return valid


@ADMIN_INTERFACE_APP.get('/ping')
def ping():
    """Ping API availability - returns a 204 or 503 depending on server readiness"""
    if ADMIN_INTERFACE_APP.ping_ready:
        response.status = 204
    else:
        response.status = 503


@ADMIN_INTERFACE_APP.get('/admin_interface/ftux')
@jwt_auth_required
def get_ftux(uci):
    """Get a list of First Time User Experiences for the Administration Interface"""
    try:
        ftux = {}
        for item in ["devices", "home", "networks", "profiles", "support", "system"]:
            ftux[item] = uci.get_option(ADMIN_PKG, "ftux", item) == "true"
        return ftux
    except UciException:
        response.status = 400
        return "Error getting ftux in configuration"


@ADMIN_INTERFACE_APP.put('/admin_interface/ftux')
@jwt_auth_required
def set_ftux(uci):
    """Update the list of First Time User Experiences for the Administration Interface"""
    try:
        updated_ftux = dict(request.json)
        validate_ftux(updated_ftux)
        for item in ["devices", "home", "networks", "profiles", "support", "system"]:
            uci.set_option(ADMIN_PKG, "ftux", item, "true" if updated_ftux[item] else "false")
        uci.persist(ADMIN_PKG)
        return updated_ftux
    except (JSONDecodeError, KeyError, UciException):
        response.status = 400
        return "Error setting ftux in configuration"


@ADMIN_INTERFACE_APP.get('/admin_interface/onboarding')
def get_onboarding(uci):
    """Get onboarding information for the Administration Interface"""
    try:
        plans = vpn.get_plans(uci)
        try:
            provider_id = uci.get_option(VPN_PKG, "active", "provider")
            provider_name = get_provider_name(provider_id)
        except UciException:
            provider_name = "unknown"
        try:
            needed = uci.get_option(ADMIN_PKG, "onboarding", "needed") == "true"
        except UciException:
            needed = False
        if ADMIN_INTERFACE_APP.model == "InvizBox Go":
            vpn_credentials_needed, ipsec_credentials_needed = False, False
            try:
                run(["dd", "if=/dev/mtd2", "bs=1", "skip=65496", "count=24"], stdout=PIPE, stderr=PIPE,
                    check=False).stdout.decode("utf-8")
                run(["dd", "if=/dev/mtd2", "bs=1", "skip=65432", "count=64"], stdout=PIPE, stderr=PIPE,
                    check=False).stdout.decode("utf-8")
            except (CalledProcessError, UnicodeDecodeError):
                vpn_credentials_needed = True
            try:
                run(["dd", "if=/dev/mtd2", "bs=1", "skip=65408", "count=24"], stdout=PIPE, stderr=PIPE,
                    check=False).stdout.decode("utf-8")
                run(["dd", "if=/dev/mtd2", "bs=1", "skip=65244", "count=64"], stdout=PIPE, stderr=PIPE,
                    check=False).stdout.decode("utf-8")
            except (CalledProcessError, UnicodeDecodeError):
                ipsec_credentials_needed = True
        else:
            vpn_credentials_needed = not path.isfile("/private/vpn_credentials.txt")
            ipsec_credentials_needed = not path.isfile("/private/ipsec_credentials.txt")
        try:
            updated_from = uci.get_option(UPDATE_PKG, "version", "updated_from")
        except UciException:
            updated_from = ""
        return {
            "credentials": {
                "ipsec": ipsec_credentials_needed,
                "vpn": vpn_credentials_needed
            },
            "model": ADMIN_INTERFACE_APP.model,
            "needed": needed,
            "plans": plans,
            "provider": provider_name,
            "updatedFrom": updated_from
        }
    except UciException:
        response.status = 400
        return "Error with admin-interface config"


@ADMIN_INTERFACE_APP.put('/admin_interface/onboarding')
@jwt_auth_required
def set_onboarding(uci):
    """Update if onboarding is still needed in the Administration Interface"""
    try:
        updated_onboarding = dict(request.json)
        if validate_onboarding(updated_onboarding):
            needed = "true" if updated_onboarding["onboarding"]["needed"] else "false"
            uci.set_option(ADMIN_PKG, "onboarding", "needed", needed)
            uci.persist(ADMIN_PKG)
            uci.parse(UPDATE_PKG)
            try:
                uci.delete_option(UPDATE_PKG, "version", "updated_from")
                uci.persist(UPDATE_PKG)
            except UciException:
                pass
            return updated_onboarding
        response.status = 400
        return "Invalid onboarding"
    except (JSONDecodeError, KeyError, UciException):
        response.status = 404
        return "Unable to update onboarding in admin-interface"
