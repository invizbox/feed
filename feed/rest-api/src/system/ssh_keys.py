""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from subprocess import run
from json.decoder import JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, request, response
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.uci import UciException


LOGGER = logging.getLogger(__name__)
SSH_PKG = "dropbear"

SSH_KEYS_APP = Bottle()
SSH_KEYS_APP.install(JWT_PLUGIN)


@SSH_KEYS_APP.get('/system/ssh_keys')
@jwt_auth_required
def get_ssh():
    """Get the SSH current keys"""
    public_keys = []
    try:
        with open("/etc/dropbear/authorized_keys", "r", encoding="utf-8") as auth_keys_file:
            for line in auth_keys_file.readlines():
                if line.strip() != "":
                    public_keys.append(line.strip())
    except FileNotFoundError:
        pass
    return {"keys": public_keys}


@SSH_KEYS_APP.put('/system/ssh_keys')
@jwt_auth_required
def put_ssh():
    """Set SSH keys"""
    try:
        ssh_json = dict(request.json)
        if not ssh_json:
            response.status = 400
            return "Empty or invalid content"
        try:
            received_keys = ssh_json["keys"]
            with open("/etc/dropbear/authorized_keys", "w", encoding="utf-8") as auth_keys_file:
                for key in received_keys:
                    auth_keys_file.write(f"{key.strip()}\n")
            run(["/etc/init.d/dropbear", "reload"], check=False)
        except (KeyError, UciException):
            response.status = 400
            return "Invalid content"
        return {
            "keys": received_keys
        }
    except JSONDecodeError:
        response.status = 400
        return "Invalid JSON content"
