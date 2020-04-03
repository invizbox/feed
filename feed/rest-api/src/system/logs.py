""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from os import path
from subprocess import run, PIPE, TimeoutExpired, CalledProcessError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, response
from plugins.plugin_jwt import JWT_PLUGIN


LOGGER = logging.getLogger(__name__)

LOGS_APP = Bottle()
LOGS_APP.install(JWT_PLUGIN)


@LOGS_APP.get('/system/logs/<log_path:path>')
@jwt_auth_required
def get_logfile(log_path):
    """Endpoint to get access any log in the /var/log directory"""
    try:
        log_file = f"/var/log/{log_path}.log"
        if not path.isfile(log_file):
            response.status = 404
            return "Non existent log file"
        proc = run(["tail", "-n", "3000", log_file], stdout=PIPE, stderr=PIPE, universal_newlines=True, timeout=5,
                   check=False)
        return {"log": proc.stdout}
    except (TimeoutExpired, CalledProcessError) as exception:
        response.status = 404
        return "Issues getting log file content: {}".format(exception.stderr)


@LOGS_APP.get('/system/logs/system')
@jwt_auth_required
def get_systemlog():
    """Endpoint to get access to the system log"""
    try:
        logread_process = run("logread", stdout=PIPE, stderr=PIPE, universal_newlines=True, timeout=5, check=False)
        return {"log": logread_process.stdout}
    except (TimeoutExpired, CalledProcessError) as exception:
        response.status = 400
        return "Problem running logread: {}".format(exception.stderr)


@LOGS_APP.get('/system/logs/kernel')
@jwt_auth_required
def get_kernellog():
    """Endpoint to get access to the kernel log"""
    try:
        logread_process = run("dmesg", stdout=PIPE, stderr=PIPE, universal_newlines=True, timeout=5, check=False)
        return {"log": logread_process.stdout}
    except (TimeoutExpired, CalledProcessError) as exception:
        response.status = 400
        return "Problem running dmesg: {}".format(exception.stderr)
