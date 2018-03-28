-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local http = require "luci.http"
local translate = require "luci.i18n"
local uci = require("uci").cursor()
local dispatcher = require "luci.dispatcher"
local utils = require("invizboxutils")


local map, station, ssid, pass, encryptionstring, dummyencryption, encryption, disabled, dummyvalue

------------------------------
--  MAP SECTION TO CONFIG FILE
------------------------------

map = cbi.Map("wireless", translate.translate("Choose Network"))
map.template = "cbi/wizardmap"
map.anonymous = true
map.redirect = dispatcher.build_url("wizard/complete")

local wizard_complete = uci:load("wizard") and uci:get("wizard", "main", "complete") ~= "false"

station = map:section(cbi.NamedSection, "wan", "wifi-iface", "", translate.translate("Select the WiFi hotspot to connect to:"))
station.addremove = false

ssid = station:option(cbi.ListValue, "ssid", translate.translate("WiFi Network") )
ssid.required = true
ssid.maxlength = 63
ssid.id = "ssid"
ssid.template = "cbi/invizboxlvalue"
ssid:reset_values()

encryptionstring = ""
local index, networks = utils.wifi_networks()
for _, scanssid in ipairs(index) do
    if networks[scanssid].encryption ~= "none" then
        ssid:value(scanssid, networks[scanssid].quality.."% - "..scanssid.." (Secure)")
    else
        ssid:value(scanssid, networks[scanssid].quality.."% - "..scanssid.." (Open)")
    end
    encryptionstring = encryptionstring.."<input type=\"hidden\" id=\""..scanssid..".encryption\" name=\""..scanssid..".encryption\" value=\""..networks[scanssid].encryption.."\"/>"
end

pass = station:option(cbi.Value, "key", translate.translate("WiFi Password"))
pass.template = "cbi/invizboxvalue"
pass.id = "ssidpassword"
pass.password = true
pass.validator_minlength = 8
pass.maxlength = 63

dummyencryption = station:option(cbi.DummyValue, "_dummy")
dummyencryption.template = "cbi/rawhtml"
dummyencryption.rawhtml  = true
dummyencryption.value = encryptionstring

encryption = station:option(cbi.Value, "encryption")
encryption.template = "cbi/invizboxhidden"

local selected_ssid = http.formvalue("cbid.wireless.wan.ssid") or ""

disabled = station:option(cbi.Value, "disabled")
disabled.template = "cbi/invizboxhidden"

if not wizard_complete then
    dummyvalue = station:option(cbi.DummyValue, "_aupaccept")
    dummyvalue.template = "cbi/rawhtml"
    dummyvalue.rawhtml  = true
    dummyvalue.value = '<br><div class="form-group cbi-value-field"><input class="cbi-input-checkbox" type="checkbox" id="aupaccept" name="aupaccept" checked="checked" value=""><p class="note" style="padding-top: .6em;">By using the InvizBox Go you accept the conditions in the <a href="https://invizbox.com/aup">Acceptable Use Policy</a></p></div>'
end

function map.on_before_save(self)
    self:set("wan", "encryption", http.formvalue(selected_ssid .. ".encryption"))
    self:del("wan", "disabled")
    local config_name = "known_networks"
    local section_name = utils.uci_characters(ssid:formvalue("wan"))
    uci:load(config_name)
    uci:set(config_name, section_name, "network")
    uci:set(config_name, section_name, "ssid", ssid:formvalue("wan"))
    uci:set(config_name, section_name, "key", pass:formvalue("wan"))
    uci:save(config_name)
    uci:commit(config_name)
end

return map
