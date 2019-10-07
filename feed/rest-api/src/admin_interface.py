""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from os import path
from json.decoder import JSONDecodeError
from contextlib import contextmanager
from bottle_jwt import jwt_auth_required
from bottle import Bottle, request, response
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.plugin_uci import UCI_PLUGIN
from plugins.uci import UciException
from utils.validate import validate_option


ADMIN_PKG = "admin-interface"
LOGGER = logging.getLogger(__name__)

ADMIN_INTERFACE_APP = Bottle()
ADMIN_INTERFACE_APP.install(JWT_PLUGIN)
ADMIN_INTERFACE_APP.install(UCI_PLUGIN)
ADMIN_INTERFACE_APP.ping_ready = True


@contextmanager
def hold_ping():
    """context manager function to fail ping when the device is not ready for API calls"""
    ADMIN_INTERFACE_APP.ping_ready = False
    yield
    ADMIN_INTERFACE_APP.ping_ready = True


def validate_ftux(ftux):
    """ validate the ftux object """
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
    """ validate the onboarding object """
    valid = True
    try:
        valid &= validate_option("boolean", onboarding["onboarding"])
    except KeyError:
        valid = False
    return valid


@ADMIN_INTERFACE_APP.get('/ping')
def ping():
    """simple endpoint to ping API availibility - returns a 204 or 503 depending on API readiness"""
    if ADMIN_INTERFACE_APP.ping_ready:
        response.status = 204
    else:
        response.status = 503


@ADMIN_INTERFACE_APP.get('/admin_interface/features')
@jwt_auth_required
def get_features(uci):
    """gets a list of features for the Administration Interface"""
    try:
        vpn_status = uci.get_option(ADMIN_PKG, "features", "vpn_status") == "true"
        return {"vpnStatus": vpn_status}
    except UciException:
        response.status = 400
        return "Unable to get features for the admin-interface"


@ADMIN_INTERFACE_APP.get('/admin_interface/ftux')
@jwt_auth_required
def get_ftux(uci):
    """gets a list of First Time User Experiences for the Administration Interface"""
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
    """ updates the list of First Time User Experiences for the Administration Interface"""
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
    """gets whether or not onboarding is needed in the Administration Interface"""
    try:
        vpn_credentials_needed = not path.isfile("/private/vpn_credentials.txt")
        return {
            'onboarding': uci.get_option(ADMIN_PKG, "onboarding", "needed") == "true",
            "vpnCredentials": vpn_credentials_needed
        }
    except UciException:
        response.status = 400
        return "Error with admin-interface config"


@ADMIN_INTERFACE_APP.put('/admin_interface/onboarding')
@jwt_auth_required
def set_onboarding(uci):
    """ updates whether or not onboarding is needed in the Administration Interface"""
    try:
        updated_onboarding = dict(request.json)
        validate_onboarding(updated_onboarding)
        uci.set_option(ADMIN_PKG, "onboarding", "needed", "true" if updated_onboarding["onboarding"] else "false")
        uci.persist(ADMIN_PKG)
        return updated_onboarding
    except (JSONDecodeError, KeyError, UciException):
        response.status = 404
        return "Unable to update onboarding in admin-interface"
