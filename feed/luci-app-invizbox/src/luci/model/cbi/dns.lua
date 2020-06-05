-- Copyright 2020 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local translate = require "luci.i18n"
local sys = require("luci.sys")

local map, dns_providers, dns_provider, dummyvalue, product_name

map = cbi.Map("wizard", translate.translate("DNS"))
map.anonymous = true
map:chain("dhcp")
map:chain("dns")

dns_providers = map:section(cbi.NamedSection, "main", "wizard", "", translate.translate("Choose your DNS provider:"))
dns_providers.addremove = false

dns_provider = dns_providers:option(cbi.ListValue, "dns_id", translate.translate("DNS Providers:"))
dns_provider:value("dhcp", "from Router (WAN)")
dns_provider.default = "dhcp"
map.uci:foreach("dns", "servers", function(section)
    dns_provider:value(section[".name"], section["name"])
end)

product_name = map.uci:get("wizard", "main", "product_name") or "InvizBox Go"

dummyvalue = dns_providers:option(cbi.DummyValue, "_provider")
dummyvalue.template = "cbi/dvalue"
dummyvalue.rawhtml  = true
dummyvalue.value = '<p class="note">'..translate.translate("This DNS is used by the "..product_name..
        " as well all devices in WiFi Extender mode.")..'</p>'

function map.on_commit()
    local dns_id = dns_provider:formvalue("main")
    if dns_id == "dhcp" then
        map.uci:delete("dhcp", "auto", "noresolv")
        map.uci:set("dhcp", "auto", "resolvfile", "/tmp/resolv.conf.auto")
        map.uci:delete("dhcp", "auto", "server")
        map.uci:delete("dhcp", "invizbox", "noresolv")
        map.uci:set("dhcp", "invizbox", "resolvfile", "/tmp/resolv.conf.auto")
        map.uci:set("dhcp", "invizbox", "server", {"/onion/172.31.1.1#9053"})
    else
        local new_dns_servers = {}
        for _, server in pairs(map.uci:get("dns", dns_id, "dns_server")) do
            table.insert(new_dns_servers, server)
        end
        map.uci:set("dhcp", "auto", "noresolv", "1")
        map.uci:delete("dhcp", "auto", "resolvfile")
        map.uci:set("dhcp", "auto", "server", new_dns_servers)
        map.uci:set("dhcp", "invizbox", "noresolv", "1")
        map.uci:delete("dhcp", "invizbox", "resolvfile")
        table.insert(new_dns_servers, "/onion/172.31.1.1#9053")
        map.uci:set("dhcp", "invizbox", "server", new_dns_servers)
    end
    map.uci:save("dhcp")
    map.uci:commit("dhcp")
end

function map.on_after_commit()
    sys.call("/etc/init.d/dnsmasq restart")
end

return map
