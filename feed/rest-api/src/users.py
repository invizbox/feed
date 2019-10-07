""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from subprocess import run, PIPE, SubprocessError
from json.decoder import JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, request, response
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.uci import UciException
from plugins.plugin_uci import UCI_PLUGIN
from utils.validate import validate_option


LOGGER = logging.getLogger(__name__)
REST_API_PKG = "rest-api"

USERS_APP = Bottle()
USERS_APP.install(JWT_PLUGIN)
USERS_APP.install(UCI_PLUGIN)


def validate_user(user):
    """validate a user object"""
    valid = True
    try:
        valid &= validate_option("string", user["password"])
        valid &= len(user["password"]) > 13
    except KeyError:
        valid = False
    return valid


@USERS_APP.get('/users')
@jwt_auth_required
def get_users(uci):
    """gets the list of administration interface users"""
    try:
        users_uci = uci.get_package(REST_API_PKG)
        users = [{'id': int(user["id"]), 'name': user["name"]} for user in users_uci if user[".type"] == "user"]
        return {"users": users}
    except UciException:
        response.status = 400
        return "Error getting users"


@USERS_APP.put('/users/<user_id>')
@jwt_auth_required
def put_user(user_id, uci):
    """changes a user password"""
    try:
        updated_user = dict(request.json)
        if not validate_user(updated_user):
            response.status = 400
            return "Invalid content"
        try:
            users_uci = uci.get_package(REST_API_PKG)
            user_name = next(user["name"] for user in users_uci if user[".type"] == "user" and user["id"] == user_id)
            password_input = updated_user["password"] + "\n" + updated_user["password"]
            run(['passwd', user_name], stdout=PIPE, stderr=PIPE, input=password_input, encoding='utf-8')
            uci.set_option(REST_API_PKG, str(user_id), "password", updated_user["password"])
            uci.persist(REST_API_PKG)
        except (UciException, SubprocessError):
            response.status = 400
            return "Error setting password"
        response.status = 204
        return None
    except JSONDecodeError:
        response.status = 400
        return "Invalid JSON content"
