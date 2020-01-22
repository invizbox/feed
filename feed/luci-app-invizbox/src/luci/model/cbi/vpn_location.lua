-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local translate = require "luci.i18n"
local http = require "luci.http"
local sys = require "luci.sys"
local utils = require "invizboxutils"
local isocountries = require "isocountries"

----------------------------
--  MAP SECTION TO CONFIG FILE
------------------------------

local map
map = cbi.Map("vpn", translate.translate("VPN Location"))
map.anonymous = true

local vpn_details = map:section(cbi.TypedSection, "server", "", translate.translate("Select your VPN location:"))
vpn_details.addremove = false
vpn_details.anonymous = true
vpn_details.isempty = true
vpn_details.loop = true
vpn_details.template = "cbi/tsection"

local country = vpn_details:option(cbi.ListValue, "vpncountry", translate.translate("Choose Country")..":" )
country.id = "vpncountry"
country.template = "cbi/countrylvalue"

local city = vpn_details:option(cbi.ListValue, "vpncity", translate.translate("Choose City")..":" )
city.id = "vpncity"
city.template = "cbi/citylvalue"

local dummy_value = vpn_details:option(cbi.DummyValue, "activevpn")
dummy_value.template = "cbi/hiddeninput"
dummy_value.id = "activevpn"
dummy_value.value = map:get("active", "vpn")

local country_list, city_list = {}, {}
local countries_for_servers = {}
local already_seen_country = {}
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
end)
table.sort(country_list)

for _, ordered_country in ipairs(country_list) do
    country:value(ordered_country)
end

for _, ordered_city in ipairs(city_list) do
    city:value(ordered_city.key, ordered_city.value)
end
city.countries=countries_for_servers

function map.parse(self)
    if http.formvalue("vpncity") then
        self.uci:set("vpn", "active", "vpn", utils.uci_characters(http.formvalue("vpncity")))
        self.uci:commit("vpn")
        self.apply_needed = true
        if utils.apply_vpn_config(self.uci, "vpn", "tun0", false) then
            sys.call("/etc/init.d/openvpn restart")
        end
        return self:state_handler(1)
    else
        cbi.Map.parse(self)
    end
end

return map
