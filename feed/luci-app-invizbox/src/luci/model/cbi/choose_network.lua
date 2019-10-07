-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local sys = require "luci.sys"
local translate = require "luci.i18n"
local uci = require("uci").cursor()
local dispatcher = require "luci.dispatcher"
local utils = require("invizboxutils")

local map, station, ssid, encryption, key, hidden_network, dummy_value
local wizard_not_complete = uci:load("wizard") and uci:get("wizard", "main", "complete") == "false"

------------------------------
--  MAP SECTION TO CONFIG FILE
------------------------------

map = cbi.Map("wireless", translate.translate("Choose Network"))
map.anonymous = true
if wizard_not_complete then
    map.redirect = dispatcher.build_url("wizard/complete")
end

station = map:section(cbi.NamedSection, "wan", "wifi-iface", "",
    translate.translate("Select the WiFi hotspot to connect to:"))
station.addremove = false

station:option(cbi.ListValue, "wifi-networks", "Wi-Fi Network")

ssid = station:option(cbi.Value, "ssid", translate.translate("SSID"))

encryption = station:option(cbi.ListValue, "encryption", translate.translate("Encryption"))
encryption:value("psk-mixed", "WPA/WPA2 Mixed")
encryption:value("wep", "WEP")
encryption:value("none", "None")

key = station:option(cbi.Value, "key", translate.translate("WiFi Password"))
key.password = true
key.validator_minlength = 8
key.maxlength = 63

hidden_network = station:option(cbi.Flag, "hidden_network")
hidden_network.template = "cbi/flag"
hidden_network.hidden = true

dummy_value = station:option(cbi.DummyValue, "currentssid")
dummy_value.template = "cbi/hiddeninput"
dummy_value.id = "currentssid"
dummy_value.value = map:get("wan", "ssid")

function map.on_before_save(self)
    self:del("wan", "disabled")
    local config_name = "known_networks"
    local section_name = utils.uci_characters(ssid:formvalue("wan"))
    uci:load(config_name)
    uci:set(config_name, section_name, "network")
    uci:set(config_name, section_name, "ssid", ssid:formvalue("wan"))
    uci:set(config_name, section_name, "key", key:formvalue("wan"))
    uci:save(config_name)
    uci:commit(config_name)
    sys.call("/etc/init.d/wifiwatch restart")
end

return map