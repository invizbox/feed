-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local translate = require "luci.i18n"
local http = require "luci.http"
local sys = require "luci.sys"
local utils = require "invizboxutils"
local isocountries = require "isocountries"

local map = cbi.Map("vpn", translate.translate("VPN Location"))
map.anonymous = true

local vpn_details = map:section(cbi.NamedSection, "active", "active", "",
        translate.translate("Choose your VPN configuration:"))
vpn_details.addremove = false
vpn_details.anonymous = true

local country = vpn_details:option(cbi.ListValue, "vpncountry", translate.translate("Choose Country")..":" )
country.id = "vpncountry"
country.template = "cbi/countrylvalue"

local city = vpn_details:option(cbi.ListValue, "vpncity", translate.translate("Choose City")..":" )
city.id = "vpncity"
city.template = "cbi/citylvalue"

local dummy_value = vpn_details:option(cbi.DummyValue, "activevpn")
dummy_value.template = "cbi/hiddeninput"
dummy_value.id = "activevpn"
dummy_value.value = map:get("active", "vpn_0")

local protocol = vpn_details:option(cbi.ListValue, "protocol_id", translate.translate("Choose Protocol")..":" )
map.uci:foreach("vpn", "protocol", function(section)
    if section["vpn_protocol"] ~= "IKEv2" then
        protocol:value(section[".name"], section["name"])
    end
end)

local country_list, city_list = {}, {}
local countries_for_servers = {}
local protocols_for_servers = {}
local already_seen_country = {}
local file_server = false
map.uci:foreach("vpn", "server", function(section)
    local s_country = isocountries.getcountryname(section["country"])
    local s_city = section["city"]
    local s_name = section["name"]
    if not already_seen_country[s_country] then
        table.insert(country_list, s_country)
        already_seen_country[s_country] = true
    end
    table.insert(city_list, {key=section[".name"], value=s_city.." - "..s_name})
    countries_for_servers[s_city.." - "..s_name]=s_country
    if section["protocol_id"] then
        protocols_for_servers[s_city.." - "..s_name] = section["protocol_id"]
    elseif section["filename"] then
        file_server = true
        protocols_for_servers[s_city.." - "..s_name] = {"filename"}
    end
end)
table.sort(country_list)

if file_server then
    protocol:value("filename", "From OVPN")
end

for _, ordered_country in ipairs(country_list) do
    country:value(ordered_country)
end

for _, ordered_city in ipairs(city_list) do
    city:value(ordered_city.key, ordered_city.value)
end
city.countries=countries_for_servers
city.protocols=protocols_for_servers

function map.parse(self)
    if http.formvalue("vpncity") then
        self.uci:set("vpn", "active", "protocol_id",
            utils.uci_characters(self:formvalue("cbid.vpn.active.protocol_id")))
        self.uci:set("vpn", "active", "vpn_0", utils.uci_characters(http.formvalue("vpncity")))
        self.uci:commit("vpn")
        self.apply_needed = true
        if utils.apply_vpn_config(self.uci, "vpn_0", "tun0", false) then
            sys.call("/etc/init.d/openvpn restart")
        end
        return self:state_handler(1)
    else
        cbi.Map.parse(self)
    end
end

return map
