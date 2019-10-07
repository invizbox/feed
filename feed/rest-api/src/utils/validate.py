""" Copyright 2018 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt

    simple validation of structures """
from re import match
from ipaddress import IPv4Address, IPv4Network, AddressValueError, NetmaskValueError
from datetime import datetime


def validate_mac_address(value):
    """ validate a MAC address """
    return match("[0-9a-f]{2}([-:]?)[0-9a-f]{2}(\\1[0-9a-f]{2}){4}$", value.lower()) is not None


def validate_string(value):
    """ validate a string """
    return isinstance(value, str) and len(value) <= 128


def validate_long_string(value):
    """ validate a long string """
    return isinstance(value, str) and len(value) <= 512


def validate_string_list(value):
    """ validate a list of strings """
    return isinstance(value, list) and all(isinstance(elem, str) and len(elem) <= 128 for elem in value)


def validate_ip_address(value):
    """ validate an IPv4 address """
    try:
        IPv4Address(value)
        return True
    except AddressValueError:
        return False


def validate_network(value):
    """ validate a network """
    try:
        IPv4Network("{}/{}".format(value[0], value[1]), False)
        return True
    except (AddressValueError, NetmaskValueError, ValueError, TypeError):
        return False


def validate_boolean(value):
    """ validate a boolean """
    return isinstance(value, bool)


def validate_time(value):
    """ validate a time """
    try:
        datetime.strptime(value, "%H:%M:%S")
        return True
    except (TypeError, ValueError):
        return False


def validate_day_list(value):
    """ validate a list of days """
    return isinstance(value, list) and all(elem in ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
                                           for elem in value)


def validate_integer(value):
    """ validate an integer """
    return isinstance(value, int)


def validate_option(option_type, value):
    """ validate values required for endpoints on input """
    validation_dict = {"mac_address": validate_mac_address,
                       "string": validate_string,
                       "long_string": validate_long_string,
                       "string_list": validate_string_list,
                       "ipv4_address": validate_ip_address,
                       "network": validate_network,
                       "boolean": validate_boolean,
                       "time": validate_time,
                       "day_list": validate_day_list,
                       "integer": validate_integer}
    try:
        return validation_dict[option_type](value)
    except KeyError:
        return False
