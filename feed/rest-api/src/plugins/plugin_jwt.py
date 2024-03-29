""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt

    Implementing an authentication backend for bottle-jwt
"""
from os import getenv
from bottle_jwt import JWTProviderPlugin, BaseAuthBackend
from plugins.plugin_uci import UCI_PLUGIN

JWT_SECRET = getenv("JWT_SECRET", "invizbox_jwt_secret")
REST_API_PKG = "rest-api"


class IB2Backend(BaseAuthBackend):
    """Implementing an auth backend class with at least two methods"""
    uci = UCI_PLUGIN.uci

    def authenticate_user(self, username, password):
        """Authenticate user by name and password"""
        users_uci = self.uci.get_package(REST_API_PKG)
        return_user = None
        for user in users_uci:
            user_password = "" if "password" not in user else user["password"]
            if user[".type"] == "user" and user["name"] == username and user_password == password:
                return_user = {
                    'id': int(user["id"]),
                    'username': user["name"],
                    'password': password
                }
        return return_user

    def get_user(self, user_id):
        """Retrieve user by id"""
        users_uci = self.uci.get_package(REST_API_PKG)
        try:
            user = next({'id': int(user["id"]),
                         'username': user["name"]} for user in users_uci
                        if user[".type"] == "user" and int(user["id"]) == user_id)
        except StopIteration:
            return None
        return user


JWT_PLUGIN = JWTProviderPlugin(
    keyword='jwt',
    auth_endpoint='/auth/token',
    backend=IB2Backend(),
    fields=('username', 'password'),
    secret=JWT_SECRET,
    ttl=900
)
