""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import base64
import logging
import os
from subprocess import run, STDOUT

from bottle import Bottle, HTTPResponse, response
from bottle_jwt import jwt_auth_required

from plugins.plugin_jwt import JWT_PLUGIN

LOGGER = logging.getLogger(__name__)

SNAPSHOT_APP = Bottle()
SNAPSHOT_APP.install(JWT_PLUGIN)

HEADERS = {
    'Content-Transfer-Encoding': 'gzip',
    'Content-Type': 'application/gzip',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Accept, Content-Type, X-Requested-With, X-CSRF-Token, Authorization'
}


def anonymise():
    """ helper function to anonymise the snapshot content """
    run(["sed", "-i", "-E", "s/option key .+/option key 'anonymised'/", "/tmp/snapshot/config/known_networks"],
        check=False)
    run(["sed", "-i", "-E", "s/option password .+/option password 'anonymised'/", "/tmp/snapshot/config/rest-api"],
        check=False)
    run(["sed", "-i", "-E", "s/option key .+/option key 'anonymised'/", "/tmp/snapshot/config/wireless"], check=False)
    run(["sed", "-i", "-E", "s/option username .+/option username 'anonymised'/", "/tmp/snapshot/config/vpn"],
        check=False)
    run(["sed", "-i", "-E", "s/option eap_identity .+/option eap_identity 'anonymised'/", "/tmp/snapshot/config/ipsec"],
        check=False)
    run(["sed", "-i", "-E", "s/option eap_password .+/option eap_password 'anonymised'/", "/tmp/snapshot/config/ipsec"],
        check=False)


@SNAPSHOT_APP.get('/system/snapshot')
@jwt_auth_required
def get_snapshot():
    """
    gets a snapshot of the router's configuration useful for troubleshooting a support issue
    """
    run(["rm", "-rf", "/tmp/snapshot"], check=False)
    run(["mkdir", "-p", "/tmp/snapshot"], check=False)
    run(["cp", "-r", "/etc/config", "/tmp/snapshot"], check=False)
    run(["cp", "-r", "/etc/profiles.json", "/tmp/snapshot"], check=False)
    run(["cp", "-r", "/var/log", "/tmp/snapshot"], check=False)
    with open("/tmp/snapshot/top.txt", "w", encoding="utf-8") as out_file:
        run(["top", "-n", "1"], stdout=out_file, stderr=STDOUT, check=False)
    with open("/tmp/snapshot/ps.txt", "w", encoding="utf-8") as out_file:
        run(["ps"], stdout=out_file, stderr=STDOUT, check=False)
    with open("/tmp/snapshot/logread.txt", "w", encoding="utf-8") as out_file:
        run(["logread"], stdout=out_file, stderr=STDOUT, check=False)
    with open("/tmp/snapshot/dmesg.txt", "w", encoding="utf-8") as out_file:
        run(["dmesg"], stdout=out_file, stderr=STDOUT, check=False)
    with open("/tmp/snapshot/ifconfig.txt", "w", encoding="utf-8") as out_file:
        run(["ifconfig"], stdout=out_file, stderr=STDOUT, check=False)
    with open("/tmp/snapshot/iptables-save.txt", "w", encoding="utf-8") as out_file:
        run(["iptables-save"], stdout=out_file, stderr=STDOUT, check=False)
    with open("/tmp/snapshot/nslookup.txt", "w", encoding="utf-8") as out_file:
        run(["nslookup", "invizbox.com"], stdout=out_file, stderr=STDOUT, check=False)
    with open("/tmp/snapshot/route.txt", "w", encoding="utf-8") as out_file:
        run(["route"], stdout=out_file, stderr=STDOUT, check=False)
    with open("/tmp/snapshot/traceroute.txt", "w", encoding="utf-8") as out_file:
        run(["traceroute", "-w", "1", "-q", "1", "-m", "60", "invizbox.com"], stdout=out_file, stderr=STDOUT,
            check=False)
    anonymise()
    run(["tar", "-zcf", "snapshot.tar.gz", "./snapshot"], cwd="/tmp", check=False)
    root = os.path.abspath('./') + os.sep
    filename = os.path.abspath(os.path.join(root, '/tmp/snapshot.tar.gz'))
    try:
        with open(filename, 'rb') as body:
            data = body.read()
    except (FileNotFoundError, IOError):
        response.status = 400
        return "Error getting snapshot"
    b64_payload = base64.b64encode(data).decode()
    return HTTPResponse({'b64_data': b64_payload}, **HEADERS)
