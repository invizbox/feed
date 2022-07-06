""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from bottle_jwt import jwt_auth_required
from bottle import Bottle, response
from plugins.plugin_uci import UCI_PLUGIN
from plugins.uci import UciException
from plugins.plugin_jwt import JWT_PLUGIN

LOGGER = logging.getLogger(__name__)
BLACKLISTS_PKG = "blacklists"

BLACKLISTS_APP = Bottle()
BLACKLISTS_APP.install(JWT_PLUGIN)
BLACKLISTS_APP.install(UCI_PLUGIN)


@BLACKLISTS_APP.get('/system/blacklists')
@jwt_auth_required
def get_blacklists(uci):
    """List the DNS Blacklists that can be used in profiles"""
    try:

        blacklists = [{"id": blacklist["id"],
                       "name": blacklist["name"],
                       "source": blacklist["source"],
                       "description": blacklist["description"]}
                      for blacklist in uci.get_package(BLACKLISTS_PKG) if blacklist[".type"] == "blacklist"]
        return {"blacklists": blacklists}
    except UciException:
        response.status = 400
        return "Error getting blacklists information"
