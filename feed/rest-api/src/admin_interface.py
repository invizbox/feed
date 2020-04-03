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


def validate_features(features):
    """ validate the features object """
    onboarding_needed = True
    try:
        onboarding_needed &= validate_option("boolean", features["onboarding"]["needed"])
    except (KeyError, TypeError):
        onboarding_needed = False
    return onboarding_needed


@ADMIN_INTERFACE_APP.get('/ping')
def ping():
    """simple endpoint to ping API availibility - returns a 204 or 503 depending on API readiness"""
    if ADMIN_INTERFACE_APP.ping_ready:
        response.status = 204
    else:
        response.status = 503


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


@ADMIN_INTERFACE_APP.get('/admin_interface/features')
def get_features(uci):
    """gets a list of features for the Administration Interface"""
    try:
        try:
            openvpn_credentials_text = uci.get_option(ADMIN_PKG, "features", "openvpn_credentials_text")
        except UciException:
            openvpn_credentials_text = ''
        openvpn_credentials_url = uci.get_option(ADMIN_PKG, "features", "openvpn_credentials_url")
        try:
            ipsec_credentials_text = uci.get_option(ADMIN_PKG, "features", "ipsec_credentials_text")
        except UciException:
            ipsec_credentials_text = ''
        ipsec_credentials_url = uci.get_option(ADMIN_PKG, "features", "ipsec_credentials_url")
        onboarding_nedeed = uci.get_option(ADMIN_PKG, "features", "onboarding_needed") == "true"
        separate_ipsec_credentials = uci.get_option(ADMIN_PKG, "features", "separate_ipsec_credentials") == "true"
        ipsec_credentials_needed = separate_ipsec_credentials and not path.isfile("/private/ipsec_credentials.txt")
        vpn_credentials_needed = not path.isfile("/private/vpn_credentials.txt")
        try:
            support_url = uci.get_option(ADMIN_PKG, "features", "support_url")
        except UciException:
            support_url = ''
        try:
            support_email = uci.get_option(ADMIN_PKG, "features", "support_email")
        except UciException:
            support_email = ''
        vpn_from_account = uci.get_option(ADMIN_PKG, "features", "vpn_from_account") == "true"
        vpn_status = uci.get_option(ADMIN_PKG, "features", "vpn_status") == "true"
        return {
            "credentials": {
                "ipsec": {
                    "text": ipsec_credentials_text,
                    "url": ipsec_credentials_url
                },
                "openvpn": {
                    "text": openvpn_credentials_text,
                    "url": openvpn_credentials_url
                },
                "separateIpsecCredentials": separate_ipsec_credentials,
                "vpnFromAccount": vpn_from_account,
            },
            'onboarding': {
                "ipsecCredentials": ipsec_credentials_needed,
                "needed": onboarding_nedeed,
                "vpnCredentials": vpn_credentials_needed
            },
            "support": {
                "url": support_url,
                "email": support_email
            },
            "vpnStatus": vpn_status
        }
    except UciException:
        response.status = 400
        return "Error with admin-interface config"


@ADMIN_INTERFACE_APP.put('/admin_interface/features')
@jwt_auth_required
def set_features(uci):
    """ updates whether or not the onboarding feature is still needed in the Administration Interface"""
    try:
        updated_features = dict(request.json)
        if validate_features(updated_features):
            onboarding_needed = "true" if updated_features["onboarding"]["needed"] else "false"
            uci.set_option(ADMIN_PKG, "features", "onboarding_needed", onboarding_needed)
            uci.persist(ADMIN_PKG)
            return updated_features
        response.status = 400
        return "Invalid features"
    except (JSONDecodeError, KeyError, UciException):
        response.status = 404
        return "Unable to update onboarding in admin-interface"
