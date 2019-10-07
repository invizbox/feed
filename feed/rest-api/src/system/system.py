""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from os import system
from subprocess import run
from json.decoder import JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, response, request
from plugins.plugin_uci import UCI_PLUGIN
from plugins.uci import UciException
from plugins.plugin_jwt import JWT_PLUGIN
from utils.iso import TZ_DATA
from utils.validate import validate_option
from admin_interface import ADMIN_INTERFACE_APP

SYSTEM_PKG = "system"
LOGGER = logging.getLogger(__name__)

SYSTEM_APP = Bottle()
SYSTEM_APP.install(JWT_PLUGIN)
SYSTEM_APP.install(UCI_PLUGIN)


@SYSTEM_APP.get('/system/reboot')
@jwt_auth_required
def reboot():
    """reboots the device"""
    LOGGER.warning("Rebooting.")
    ADMIN_INTERFACE_APP.ping_ready = False
    system(". /bin/ledcontrol.ash; led_info_quick_flashing")
    system("/sbin/reboot &")


@SYSTEM_APP.get('/system/reset')
@jwt_auth_required
def reset():
    """resets the device"""
    LOGGER.warning("Resetting to first boot.")
    ADMIN_INTERFACE_APP.ping_ready = False
    system(". /bin/ledcontrol.ash; led_info_quick_flashing")
    system("firstboot -y")
    system("/sbin/reboot &")


@SYSTEM_APP.get('/system/timezone')
@jwt_auth_required
def get_timezone(uci):
    """resets the device"""
    try:
        system_uci = uci.get_package(SYSTEM_PKG)
        system_section = next(section for section in system_uci
                              if section[".type"] == "system" and section["id"] == "system")
        current_timezone = system_section["zonename"]
        return {"current": current_timezone.replace(' ', '_'),
                "available": list(TZ_DATA.keys())}
    except (UciException, StopIteration):
        response.status = 400
        return "Error reading system settings"


def validate_timezone(updated_timezone):
    """ validate a timezone """
    valid = True
    try:
        valid &= validate_option("string", updated_timezone["current"])
    except KeyError:
        valid = False
    return valid


@SYSTEM_APP.put('/system/timezone')
@jwt_auth_required
def set_timezone(uci):
    """sets the device timezone"""
    try:
        updated_timezone = dict(request.json)
        if validate_timezone(updated_timezone) and updated_timezone["current"] in TZ_DATA:
            uci.set_option(SYSTEM_PKG, "system", "zonename", updated_timezone["current"].replace('_', ' '))
            uci.set_option(SYSTEM_PKG, "system", "timezone", TZ_DATA[updated_timezone["current"]])
            uci.persist(SYSTEM_PKG)
            run(["/etc/init.d/system", "reload"])
            return updated_timezone
        response.status = 400
        return "Invalid timezone"
    except (UciException, JSONDecodeError):
        response.status = 400
        return "Error setting the timezone"


def validate_led(updated_led):
    """ validate an LED setting """
    valid = True
    try:
        valid &= validate_option("string", updated_led["status"])
        valid &= updated_led["status"] in ["on", "off", "flashing", "quick_flashing"]
    except KeyError:
        valid = False
    return valid
