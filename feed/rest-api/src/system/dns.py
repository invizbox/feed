""" Copyright 2020 InvizBox Ltd
    https://www.invizbox.com/lic/license.txt
"""
import logging
from subprocess import run
from json.decoder import JSONDecodeError
from bottle_jwt import jwt_auth_required
from bottle import Bottle, request, response
from plugins.plugin_uci import UCI_PLUGIN
from plugins.uci import UciException
from plugins.plugin_jwt import JWT_PLUGIN
from utils.validate import validate_option

LOGGER = logging.getLogger(__name__)
ADMIN_PKG = "admin-interface"
DHCP_PKG = "dhcp"
DNS_PKG = "dns"

DNS_APP = Bottle()
DNS_APP.install(JWT_PLUGIN)
DNS_APP.install(UCI_PLUGIN)


def validate_dns_provider(dns_provider, uci):
    """validate a DNS Provider ID"""
    valid = True
    try:
        valid &= validate_option("string", dns_provider["dnsProviderId"])
        valid &= (dns_provider["dnsProviderId"] == "dhcp"
                  or uci.get_option(DNS_PKG, dns_provider["dnsProviderId"], ".type") == "servers")
    except (KeyError, UciException):
        return False
    return valid


@DNS_APP.get('/system/dns_providers')
@jwt_auth_required
def get_dns_providers(uci):
    """gets a list of DNS providers"""
    try:
        dns_uci = uci.get_package(DNS_PKG)
        resolv_servers = []
        try:
            with open("/tmp/resolv.conf.auto") as resolv_file:
                for line in resolv_file.readlines():
                    if line.startswith("nameserver "):
                        resolv_servers.append(line.strip().split()[1])
        except (FileNotFoundError, IOError):
            pass
        dns = [{
            "id": "dhcp",
            "name": "from Router (WAN)",
            "servers": resolv_servers
        }]
        for servers in dns_uci:
            if servers[".type"] == "servers":
                dns.append({
                    "id": servers["id"],
                    "name": servers["name"],
                    "servers": servers["dns_server"] if "dns_server" in servers else []
                })
        return {"dnsProviders": dns}
    except UciException:
        response.status = 400
        return "Error getting dns in configuration"


@DNS_APP.get('/system/dns')
@jwt_auth_required
def get_dns(uci):
    """gets the id of the DNS provider used by the InvizBox 2"""
    try:
        return {"dnsProviderId": uci.get_option(ADMIN_PKG, "invizbox", "dns_id") or "opendns"}
    except UciException:
        response.status = 400
        return "Error getting invizbox dns in configuration"


def replace_dnsmasq_servers(uci, section, provider_id):
    """helper function to replace the dnsmasq section servers"""
    local_dns_srvs = [ser for ser in uci.get_option(DHCP_PKG, section, "server") if ser.startswith("/")]
    if provider_id == "dhcp":
        try:
            uci.delete_option(DHCP_PKG, section, "noresolv")
        except UciException:
            pass
        uci.set_option(DHCP_PKG, section, "resolvfile", "/tmp/resolv.conf.auto")
        uci.set_option(DHCP_PKG, section, "server", local_dns_srvs)
    else:
        new_dns_servers = local_dns_srvs + uci.get_option(DNS_PKG, provider_id, "dns_server")
        try:
            uci.delete_option(DHCP_PKG, section, "resolvfile")
        except UciException:
            pass
        uci.set_option(DHCP_PKG, section, "noresolv", "1")
        uci.set_option(DHCP_PKG, section, "server", new_dns_servers)


@DNS_APP.put('/system/dns')
@jwt_auth_required
def put_dns(uci):
    """changes the id of the DNS provider used by the InvizBox 2"""
    try:
        dns_json = dict(request.json)
        if not dns_json:
            response.status = 400
            return "Empty or invalid content"
        try:
            if not validate_dns_provider(dns_json, uci):
                response.status = 400
                return "Invalid DNS Provider"
            new_provider = dns_json["dnsProviderId"]
            if new_provider != uci.get_option(ADMIN_PKG, "invizbox", "dns_id"):
                uci.set_option(ADMIN_PKG, "invizbox", "dns_id", dns_json["dnsProviderId"])
                uci.persist(ADMIN_PKG)
                replace_dnsmasq_servers(uci, "invizbox", dns_json["dnsProviderId"])
                uci.persist(DHCP_PKG)
                run(["/etc/init.d/dnsmasq", "reload"], check=False)
        except UciException:
            response.status = 400
            return "Error setting new DNS provider"
        return {
            "dnsProviderId": dns_json["dnsProviderId"]
        }
    except JSONDecodeError:
        response.status = 400
        return "Invalid JSON content"
