""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from subprocess import Popen, PIPE, CalledProcessError
from json.decoder import JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, request, response
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.plugin_uci import UCI_PLUGIN
from plugins.uci import UciException, uci_characters
from utils.validate import validate_option
import profiles

DEVICE_PKG = "devices"
FIREWALL_PKG = "firewall"
LOGGER = logging.getLogger(__name__)

DEVICES_APP = Bottle()
DEVICES_APP.install(JWT_PLUGIN)
DEVICES_APP.install(UCI_PLUGIN)


def validate_device(device, new=False):
    """ validate a device """
    valid = True
    try:
        valid &= validate_option("string", device["name"])
        if new:
            valid &= validate_option("mac_address", device["macAddress"])
        else:
            valid &= "mac_address" not in device
        valid &= validate_option("string", device["type"])
        if "ipAddress" in device:
            valid = False
    except KeyError:
        valid = False
    return valid


def get_alive_devices(ip_addresses):
    """helper function to check which devices are in fact still connected when their IP is listed in uci"""
    try:
        alive_devices = []
        process = Popen(["fping", "-4", "-c", "1", "-H", "1", "-r", "1", "-q", "--alive", *ip_addresses], stderr=PIPE)
        output = process.communicate()[1]
        for line in output.decode('ascii').splitlines():
            if "1/1/0%" in line:
                alive_devices.append(line.split(" ")[0])
        return alive_devices
    except CalledProcessError:
        return []


def get_devices(uci, include_ips=False):
    """" helper function to get all information related to devices from UCI """
    uci.parse(DEVICE_PKG)
    devices_uci = uci.get_package(DEVICE_PKG)
    if include_ips:
        ips = [device["ip_address"] for device in devices_uci
               if device[".type"] == "device" and "ip_address" in device and device["ip_address"]]
        alive_ips = get_alive_devices(ips)
    devices = [
        {
            "id": device["id"],
            "name": device["name"] if "name" in device else "",
            "macAddress": device["mac_address"],
            "ipAddress": device["ip_address"] if include_ips and "ip_address" in device
                         and device["ip_address"] in alive_ips else "",
            'type': device["type"] if "type" in device else ""
        }
        for device in devices_uci if device[".type"] == "device"
    ]
    return devices


@DEVICES_APP.get('/devices')
@jwt_auth_required
def list_devices(uci):
    """ list known devices """
    try:
        return {"devices": get_devices(uci, True)}
    except UciException:
        response.status = 400
        return "Error with devices"


@DEVICES_APP.get('/devices/<device_id>')
@jwt_auth_required
def get_device(device_id, uci):
    """ list a specific device """
    LOGGER.debug("get_device() called")
    try:
        devices = get_devices(uci, True)
        device = next(device for device in devices if device["id"] == device_id)
        return device
    except (UciException, StopIteration):
        response.status = 404
        return "Invalid id"


@DEVICES_APP.post('/devices')
@jwt_auth_required
def create_device(uci):
    """ create a new device """
    try:
        device = dict(request.json)
        if not validate_device(device, True):
            response.status = 400
            return "Empty or invalid content"
        try:
            uci.get_config(DEVICE_PKG, uci_characters(device["macAddress"]))
            response.status = 400
            return "Duplicate device (MAC Address)"
        except UciException:
            pass
        new_device = {
            ".type": "device",
            "id": uci_characters(device["macAddress"]),
            "name": device["name"],
            "mac_address": device["macAddress"],
            'type': device["type"]
        }
        uci.add_config(DEVICE_PKG, new_device)
        uci.persist(DEVICE_PKG)
        response.status = 201
        return {
            "id": new_device["id"],
            "name": new_device["name"],
            "macAddress": new_device["mac_address"],
            "ipAddress": "",
            'type': new_device["type"]
        }
    except (JSONDecodeError, UciException):
        response.status = 400
        return "Invalid content"


@DEVICES_APP.delete('/devices/<device_id>')
@jwt_auth_required
def delete_device(device_id, uci):
    """ delete a specific device """
    LOGGER.debug("delete_device() called")
    try:
        devices = get_devices(uci)
        mac_address = next(device["macAddress"] for device in devices if device["id"] == device_id)
        uci.get_config(DEVICE_PKG, device_id)
        uci.delete_config(DEVICE_PKG, device_id)
        uci.persist(DEVICE_PKG)
        profiles.delete_device_from_profiles(device_id)
        for rule in uci.get_package(FIREWALL_PKG):
            if ".type" in rule and rule[".type"] == "rule" and "id" in rule and rule["id"]:
                if "src_mac" in rule and rule["src_mac"] == mac_address:
                    uci.delete_config(FIREWALL_PKG, rule["id"])
        uci.persist(FIREWALL_PKG)
        response.status = 204
        return ""
    except (StopIteration, UciException):
        response.status = 404
        return "Invalid id"


@DEVICES_APP.put('/devices/<device_id>')
@jwt_auth_required
def update_device(device_id, uci):
    """ update a specific device """
    LOGGER.debug("update_device() called")
    try:
        devices = get_devices(uci, True)
        device = next(device for device in devices if device["id"] == device_id)
    except (StopIteration, UciException):
        response.status = 404
        return "Invalid id"
    try:
        updated_device = dict(request.json)
        if not validate_device(updated_device):
            response.status = 400
            return "Empty or invalid fields"
        if device["name"] != updated_device["name"] or device["type"] != updated_device["type"]:
            device["name"] = updated_device["name"]
            uci.set_option(DEVICE_PKG, device_id, "name", updated_device["name"])
            device["type"] = updated_device["type"]
            uci.set_option(DEVICE_PKG, device_id, "type", updated_device["type"])
            uci.persist(DEVICE_PKG)
        return device
    except (JSONDecodeError, UciException, KeyError, TypeError):
        response.status = 400
        return "Invalid content"
