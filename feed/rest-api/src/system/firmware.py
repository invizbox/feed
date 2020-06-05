""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from os import system, path
from os.path import splitext
from json.decoder import JSONDecodeError
from hashlib import sha256
from bottle_jwt import jwt_auth_required
from bottle import Bottle, request, response
from plugins.plugin_uci import UCI_PLUGIN
from plugins.plugin_jwt import JWT_PLUGIN
from admin_interface import ADMIN_INTERFACE_APP


LOGGER = logging.getLogger(__name__)

FIRMWARE_APP = Bottle()
FIRMWARE_APP.install(JWT_PLUGIN)
CHUNK_SIZE = 65536


@FIRMWARE_APP.post('/system/firmware/upload')
@jwt_auth_required
def upload_firmware():
    """upload the firmware file and report SHA256"""
    upload = request.files.get('file')  # pylint: disable=no-member
    _, extension = splitext(upload.filename)
    if extension != '.bin':
        response.status = 422
        return 'File extension must be ".bin"'
    upload.filename = "firmware.img.gz"
    upload.save("/tmp", overwrite=True, chunk_size=CHUNK_SIZE)
    sha256_handler_ = sha256()
    try:
        with open("/tmp/firmware.img.gz", 'rb') as firmware_file:
            for block in iter(lambda: firmware_file.read(CHUNK_SIZE), b''):
                sha256_handler_.update(block)
    except FileNotFoundError:
        response.status = 422
        return "Error dealing with uploaded file."
    system("rm /tmp/*.img")
    if system(f"gunzip -c /tmp/firmware.img.gz > /tmp/{sha256_handler_.hexdigest()}.img") != 0 \
       or system(f"/sbin/sysupgrade --test /tmp/{sha256_handler_.hexdigest()}.img > /tmp/sysupgrade_test.txt") != 0 \
            or system("grep -q 'Invalid partition table on ' /tmp/sysupgrade_test.txt") == 0:
        response.status = 422
        return 'Uploaded file is not a valid InvizBox 2 firmware.'
    return {"SHA256": sha256_handler_.hexdigest()}


@FIRMWARE_APP.post('/system/firmware/flash')
@jwt_auth_required
def flash_firmware():
    """flash the previously uploaded firmware"""
    try:
        json_content = dict(request.json)
        if not json_content:
            response.status = 400
            return "Empty or invalid content"
        try:
            received_sha256_sum = json_content["SHA256"]
            drop_config = json_content["dropConfiguration"]
        except KeyError:
            response.status = 400
            return "Missing element"
        if path.isfile(f"/tmp/{received_sha256_sum}.img"):
            ADMIN_INTERFACE_APP.ping_ready = False
            UCI_PLUGIN.uci.persist = lambda *_: None
            system(". /bin/ledcontrol.ash; led_info_quick_flashing")
            if isinstance(drop_config, bool) and drop_config:
                LOGGER.error("calling sysupgrade with -n")
                system(f"/sbin/sysupgrade -n /tmp/{received_sha256_sum}.img &")
            else:
                LOGGER.error("calling sysupgrade without -n")
                system(f"/sbin/sysupgrade /tmp/{received_sha256_sum}.img &")
        else:
            response.status = 400
            return "SHA256 hash doesn't match the previously uploaded file"
        return "OK"
    except JSONDecodeError:
        response.status = 400
        return "Invalid JSON content"


@FIRMWARE_APP.post('/system/firmware/flash_new')
@jwt_auth_required
def flash_new_firmware():
    """flash the firmware downloaded by the update process (see newFirmware in /system/info/generic)"""
    try:
        json_content = dict(request.json)
        if not json_content:
            response.status = 400
            return "Empty or invalid content"
        try:
            version = json_content["version"]
            drop_config = json_content["dropConfiguration"]
        except KeyError:
            response.status = 400
            return "Missing element"
        if system(f"mv /etc/update/firmware/new_firmware-{version}-sysupgrade.bin /tmp/firmware.img.gz") == 0 \
                and system(f"gunzip -f /tmp/firmware.img.gz > /tmp/firmware.img") == 0:
            ADMIN_INTERFACE_APP.ping_ready = False
            UCI_PLUGIN.uci.persist = lambda *_: None
            system(". /bin/ledcontrol.ash; led_info_quick_flashing")
            if isinstance(drop_config, bool) and drop_config:
                LOGGER.error("calling sysupgrade with -n")
                system(f"/sbin/sysupgrade -n /tmp/firmware.img &")
            else:
                LOGGER.error("calling sysupgrade without -n")
                system(f"/sbin/sysupgrade /tmp/firmware.img &")
        else:
            response.status = 400
            return "Missing firmware file"
        return "OK"
    except JSONDecodeError:
        response.status = 400
        return "Invalid JSON content"
