""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging.handlers
from datetime import datetime, timedelta
from hashlib import sha256
from glob import glob
from uuid import uuid4
from http.cookies import Morsel
from ua_parser import user_agent_parser
from bottle_jwt import jwt_auth_required
from bottle import Bottle, response, request
from plugins.plugin_jwt import JWT_PLUGIN
from plugins.plugin_uci import UCI_PLUGIN
from plugins.uci import UciException
from devices import get_devices

WIRELESS_PKG = "wireless"
REST_API_PKG = "rest-api"
LOGGER = logging.getLogger(__name__)

AUTH_APP = Bottle()
AUTH_APP.install(JWT_PLUGIN)
AUTH_APP.install(UCI_PLUGIN)


def get_identifier():
    """Get the unique identifier for the InvizBox"""
    try:
        radio_path = UCI_PLUGIN.uci.get_option(WIRELESS_PKG, "radio0", "path")
        mac_file_path = glob(f"/sys/devices/{radio_path}/ieee80211/phy*/macaddress")[0]
        with open(mac_file_path, "r", encoding="utf-8") as mac_file:
            return sha256(mac_file.readline().rstrip().encode()).hexdigest()[:16]
    except (FileNotFoundError, IndexError, IOError, UciException):
        return "b23a6a8439c0dde5"  # (sha56sum("unknown".encode()).hexdigest()[:16])


AUTH_APP.ib_identifier = get_identifier()


@AUTH_APP.route("/auth/authenticated")
@jwt_auth_required
def authenticated():
    """Route to validate authentication as only authenticated users can see this"""
    return {"authenticated": True}


@AUTH_APP.get("/auth/newer_token")
@jwt_auth_required
def newer_token():
    """Authorisation point - used to get a newer access token when authenticated"""
    token, expires = JWT_PLUGIN.provider.create_token(request.get_user())
    return {"token": token, "expires": str(expires)}


@AUTH_APP.get("/auth/access_token")
def access_token(uci):
    """Authorisation point - used to get an access token from a refresh token (cookie)"""
    try:
        try:
            token_cookie = next(value for name, value in request.cookies.iteritems()  # pylint: disable=no-member
                                if name == f"refresh_{AUTH_APP.ib_identifier}")
        except StopIteration:
            # Old cookie format for IB firmware <= 0.1.7
            token_cookie = next(value for name, value in request.cookies.iteritems() if name == "api_refresh")  # pylint: disable=no-member
        try:
            client_ip = request.environ.get("REMOTE_ADDR")
            devices = get_devices(uci, True)
            device_id = next(device["id"] for device in devices
                             if "ipAddress" in device and device["ipAddress"] == client_ip)
        except StopIteration:
            device_id = None
        rest_uci = uci.get_package(REST_API_PKG)
        ua_dict = user_agent_parser.Parse(request.environ.get("HTTP_USER_AGENT"))
        try:
            token = next(token for token in rest_uci if token[".type"] == "refresh_token"
                         and token["token"] == token_cookie
                         and token["ua_brand"] == (ua_dict["device"]["brand"] or "Other")
                         and token["ua_family"] == (ua_dict["device"]["family"] or "Other")
                         and token["ua_model"] == (ua_dict["device"]["model"] or "Other")
                         and token["ua_os"] == (ua_dict["os"]["family"] or "Other")
                         and token["ua_agent"] == (ua_dict["user_agent"]["family"] or "Other"))
        except StopIteration:
            response.status = 400
            return "Error validating the refresh token"
        if device_id and token["device_id"] == "":
            uci.set_option(REST_API_PKG, token["id"], "device_id", device_id)
            uci.persist(REST_API_PKG)
        try:
            user = next({"id": int(user["id"]), "username": user["name"]} for user in rest_uci
                        if user[".type"] == "user" and user["id"] == token["user"])
        except StopIteration:
            response.status = 400
            return "Error validating the refresh token"
        new_access_tk, expires = JWT_PLUGIN.provider.create_token(user)
        return {"token": new_access_tk, "expires": str(expires), "refresh_token_id": token["id"]}
    except (StopIteration, UciException, TypeError):
        response.status = 400
        return "Error validating the refresh token"


@AUTH_APP.get("/auth/refresh_tokens")
@jwt_auth_required
def get_refresh_tokens(uci):
    """Get a list of token ID, User Agents, Devices pairs for which a refresh token was issued"""
    try:
        token_uci = uci.get_package(REST_API_PKG)
        tokens = [{"id": token["id"],
                   "user": token["user"],
                   "userAgent": {
                       "device": {
                           "brand": token["ua_brand"],
                           "family": token["ua_family"],
                           "model": token["ua_model"]},
                       "os": token["ua_os"],
                       "agent": token["ua_agent"]},
                   "deviceId": token["device_id"] if token["device_id"] != "" else None} for token in token_uci
                  if token[".type"] == "refresh_token" and token["user"] == str(request.get_user()["id"])]
        return {"refresh_tokens": tokens}
    except UciException:
        response.status = 400
        return "Error getting refresh tokens"


@AUTH_APP.post("/auth/refresh_tokens")
@jwt_auth_required
def new_refresh_token(uci):
    """Authorisation point - used to get a refresh token"""
    try:
        client_ip = request.environ.get("REMOTE_ADDR")
        host = request.environ.get("HTTP_HOST")
        devices = get_devices(uci, True)
        try:
            device_id = next(device["id"] for device in devices
                             if "ipAddress" in device and device["ipAddress"] == client_ip)
        except StopIteration:
            device_id = None
        ua_dict = user_agent_parser.Parse(request.environ.get("HTTP_USER_AGENT"))
        created_token = {
            ".type": "refresh_token",
            "id": uuid4().hex,
            "user": str(request.get_user()["id"]),
            "token": uuid4().hex,
            "ua_brand": ua_dict["device"]["brand"] or "Other",
            "ua_family": ua_dict["device"]["family"] or "Other",
            "ua_model": ua_dict["device"]["model"] or "Other",
            "ua_os": ua_dict["os"]["family"] or "Other",
            "ua_agent": ua_dict["user_agent"]["family"] or "Other",
            "device_id": device_id if device_id else "None"
        }
        uci.add_config(REST_API_PKG, created_token)
        uci.persist(REST_API_PKG)
        # next line - see https://github.com/bottlepy/bottle/pull/983 until 0.13 release
        Morsel._reserved["same-site"] = "SameSite"  # pylint: disable=protected-access
        response.set_cookie(f"refresh_{AUTH_APP.ib_identifier}", created_token["token"],
                            path="/api/auth/access_token", domain=host, httponly=True, same_site="strict")
        return {
            "id": created_token["id"],
            "user": created_token["user"],
            "userAgent": {
                "device": {
                    "brand": created_token["ua_brand"],
                    "family": created_token["ua_family"],
                    "model": created_token["ua_model"]},
                "os": created_token["ua_os"],
                "agent": created_token["ua_agent"]},
            "deviceId": device_id
        }
    except (UciException, TypeError):
        response.status = 400
        return "Error creating a refresh token"


@AUTH_APP.delete("/auth/refresh_tokens/<token_id>")
@jwt_auth_required
def revoke_refresh_token(token_id, uci):
    """Authorisation point - used to revoke a refresh token"""
    # removes if exists and return 200 anyway (400 if invalid format)
    try:
        host = request.environ.get("HTTP_HOST")
        token = uci.get_config(REST_API_PKG, token_id)["token"]
        uci.delete_config(REST_API_PKG, token_id)
        uci.persist(REST_API_PKG)
        Morsel._reserved["same-site"] = "SameSite"  # pylint: disable=protected-access
        response.set_cookie(f"refresh_{AUTH_APP.ib_identifier}", token, path="/api/auth/access_token", domain=host,
                            httponly=True, same_site="strict", expires=datetime.utcnow() - timedelta(days=1))
        return ""
    except (UciException, KeyError) as exception:
        if str(exception) != "Invalid package":
            response.status = 400
            return "Error deleting refresh token"
        return ""
