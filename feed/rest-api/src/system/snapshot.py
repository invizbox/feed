""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import os
import logging
import base64
from subprocess import run, STDOUT
from bottle_jwt import jwt_auth_required
from bottle import Bottle, HTTPResponse
from plugins.plugin_jwt import JWT_PLUGIN


LOGGER = logging.getLogger(__name__)

SNAPSHOT_APP = Bottle()
SNAPSHOT_APP.install(JWT_PLUGIN)

HEADERS = {
    'Content-Transfer-Encoding': 'gzip',
    'Content-Type': 'application/gzip',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Accept, Content-Type, X-Requested-With, ' \
                                   'X-CSRF-Token, Authorization'
}


def anonymise():
    """ helper function to anonymise the snapshot content """
    run(["sed", "-i", "-E", "s/option password .+/option password 'anonymised'/", "/tmp/snapshot/config/rest-api"])
    run(["sed", "-i", "-E", "s/option key .+/option key 'anonymised'/", "/tmp/snapshot/config/wireless"])


@SNAPSHOT_APP.get('/system/snapshot')
@jwt_auth_required
def get_snapshot():
    """
    gets a snapshot of the router's configuration useful for troubleshooting a support issue
    """
    run(["rm", "-rf", "/tmp/snapshot"])
    run(["mkdir", "-p", "/tmp/snapshot"])
    run(["cp", "-r", "/etc/config", "/tmp/snapshot"])
    run(["cp", "-r", "/etc/profiles.json", "/tmp/snapshot"])
    run(["cp", "-r", "/var/log", "/tmp/snapshot"])
    with open("/tmp/snapshot/top.txt", "w") as out_file:
        run(["top", "-n", "1"], stdout=out_file, stderr=STDOUT)
    with open("/tmp/snapshot/ps.txt", "w") as out_file:
        run(["ps"], stdout=out_file, stderr=STDOUT)
    with open("/tmp/snapshot/logread.txt", "w") as out_file:
        run(["logread"], stdout=out_file, stderr=STDOUT)
    with open("/tmp/snapshot/ifconfig.txt", "w") as out_file:
        run(["ifconfig"], stdout=out_file, stderr=STDOUT)
    with open("/tmp/snapshot/iptables-save.txt", "w") as out_file:
        run(["iptables-save"], stdout=out_file, stderr=STDOUT)
    with open("/tmp/snapshot/nslookup.txt", "w") as out_file:
        run(["nslookup", "invizbox.com"], stdout=out_file, stderr=STDOUT)
    with open("/tmp/snapshot/route.txt", "w") as out_file:
        run(["route"], stdout=out_file, stderr=STDOUT)
    with open("/tmp/snapshot/traceroute.txt", "w") as out_file:
        run(["traceroute", "-w", "1", "-q", "1", "-m", "60", "invizbox.com"], stdout=out_file, stderr=STDOUT)
    anonymise()
    run(["tar", "-zcf", "snapshot.tar.gz", "./snapshot"], cwd="/tmp")
    root = os.path.abspath('./') + os.sep
    filename = os.path.abspath(os.path.join(root, '/tmp/snapshot.tar.gz'))
    body = open(filename, 'rb')
    data = body.read()
    b64_payload = base64.b64encode(data).decode()
    return HTTPResponse({'b64_data': b64_payload}, **HEADERS)
