#! /usr/bin/env python3
""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt

    This is the entry point in the REST API
"""

import logging.handlers
from signal import signal, SIGUSR1
from threading import Thread

from bottle import Bottle, response
from flup.server.fcgi import WSGIServer

from admin_interface import ADMIN_INTERFACE_APP
from auth import AUTH_APP
from devices import DEVICES_APP
from networks import NETWORKS_APP
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.plugin_uci import UCI_PLUGIN
from profiles import PROFILES_APP, aggregate_loop
from system.blacklists import BLACKLISTS_APP
from system.dns import DNS_APP
from system.firmware import FIRMWARE_APP
from system.info import INFO_APP
from system.internet import INTERNET_APP, scan
from system.logs import LOGS_APP
from system.snapshot import SNAPSHOT_APP
from system.ssh_keys import SSH_KEYS_APP
from system.system import SYSTEM_APP
from system.vpn import VPN_APP
from users import USERS_APP

logging.basicConfig(level=logging.INFO)
ROOT_LOGGER = logging.getLogger()
SYSLOG_HANDLER = logging.handlers.SysLogHandler(address='/dev/log', facility=logging.handlers.SysLogHandler.LOG_DAEMON)
FORMATTER = logging.Formatter('%(module)s[%(process)d]: %(message)s')
SYSLOG_HANDLER.setFormatter(FORMATTER)
ROOT_LOGGER.addHandler(SYSLOG_HANDLER)
LOGGER = logging.getLogger(__name__)

ADMIN_PKG = "admin-interface"
BLACKLISTS_PKG = "blacklists"
DHCP_PKG = "dhcp"
UPDATE_PKG = "update"
VPN_PKG = "vpn"
WIRELESS_PKG = "wireless"

BOTTLE_APP = Bottle()
BOTTLE_APP.install(JWT_PLUGIN)
BOTTLE_APP.merge(AUTH_APP)
BOTTLE_APP.merge(BLACKLISTS_APP)
BOTTLE_APP.merge(DEVICES_APP)
BOTTLE_APP.merge(DNS_APP)
BOTTLE_APP.merge(FIRMWARE_APP)
BOTTLE_APP.merge(ADMIN_INTERFACE_APP)
BOTTLE_APP.merge(INFO_APP)
BOTTLE_APP.merge(INTERNET_APP)
BOTTLE_APP.merge(LOGS_APP)
BOTTLE_APP.merge(NETWORKS_APP)
BOTTLE_APP.merge(PROFILES_APP)
BOTTLE_APP.merge(SNAPSHOT_APP)
BOTTLE_APP.merge(SSH_KEYS_APP)
BOTTLE_APP.merge(SYSTEM_APP)
BOTTLE_APP.merge(USERS_APP)
BOTTLE_APP.merge(VPN_APP)


@BOTTLE_APP.hook('after_request')
def enable_cors():
    """
    You need to add some headers to each request.
    Don't use the wildcard '*' for Access-Control-Allow-Origin in production.
    """
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'PUT, GET, POST, DELETE, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Origin, Accept, Content-Type, X-Requested-With, ' \
                                                       'X-CSRF-Token, Authorization'


@BOTTLE_APP.route('/')
def index():
    """Entry point and full documentation of the API"""
    api_calls = {}
    for route in BOTTLE_APP.routes:
        auth_required = hasattr(route.callback, 'auth_required')
        if route.rule == "/auth/token":
            route.callback.__doc__ = "Authorisation point - used to request an access token (JWT)"
        if route.rule not in api_calls:
            api_calls[route.rule] = {}
        api_calls[route.rule][route.method] = {"documentation": route.callback.__doc__,
                                               "auth_required": auth_required}
    return {"apiCalls": api_calls}


@BOTTLE_APP.error(404)
def error404(_):
    """Non existent route"""
    response.status = 404


@BOTTLE_APP.route('/<:re:.*>', method='OPTIONS')
def allow_options_calls():
    """Special route to deal with CORS from external callers on all API routes"""


@BOTTLE_APP.route('/<:re:.*>', method=['DEL', 'GET', 'POST', 'PUT'])
def explicit_404():
    """Special route to deal with CORS route matching all and sending back 405"""
    response.status = 404


def handle_usr1_signal(_signum, _frame):
    """Handle USR1 - used to reload VPN, and update configurations when modified"""
    LOGGER.info("reloading admin-interface, blacklists, dhcp, update, wireless and vpn configuration")
    UCI_PLUGIN.uci.parse(VPN_PKG)
    UCI_PLUGIN.uci.parse(ADMIN_PKG)
    UCI_PLUGIN.uci.parse(BLACKLISTS_PKG)
    UCI_PLUGIN.uci.parse(DHCP_PKG)
    UCI_PLUGIN.uci.parse(UPDATE_PKG)
    UCI_PLUGIN.uci.parse(WIRELESS_PKG)
    # handle consequences of external changes like blacklists or VPN servers
    PROFILES_APP.lists_rebuild_flag = True


def main():
    """Main function"""
    # BOTTLE_APP.run(host='127.0.0.1', port=8080, debug=True, reloader=True)
    LOGGER.info("Starting the REST API Bottle App")
    initial_scan_thread = Thread(target=scan, daemon=True)
    initial_scan_thread.start()
    aggregate_thread = Thread(target=aggregate_loop, args=(UCI_PLUGIN.uci,), daemon=True)
    aggregate_thread.start()
    signal(SIGUSR1, handle_usr1_signal)
    WSGIServer(BOTTLE_APP, bindAddress="/var/rest-api.fastcgi.py.socket", umask=0o000).run()
    aggregate_thread.join()
    LOGGER.info("Stopped the REST API Bottle App")


if __name__ == "__main__":
    main()
