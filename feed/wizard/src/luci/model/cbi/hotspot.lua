-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

------------------------------
--  MAP SECTION TO CONFIG FILE
------------------------------
local cbi = require "luci.cbi"
local uci = require "uci".cursor()
local translate = require "luci.i18n"
local sys = require "luci.sys"
local dispatcher = require "luci.dispatcher"

local map, access_point, ssid, pass, dummyvalue

map = cbi.Map("wireless", translate.translate("Hotspot"))
map.template = "cbi/wizardmap"
map.anonymous = true

access_point = map:section(cbi.NamedSection, "ap", "wifi-iface", "", translate.translate("Name the InvizBox Go Wifi Hotspot"))
access_point.addremove = false

ssid = access_point:option(cbi.Value, "ssid", translate.translate("Hotspot Name") )
ssid.required = true
ssid.maxlength = 63
ssid.template = "cbi/invizboxvalue"

pass = access_point:option(cbi.Value, "key", translate.translate("Hotspot Password"))
pass.template = "cbi/invizboxpassword"
pass.password = true
pass.required = true
pass.id = "hotspot_password"
pass.validator_equals = "#hotspot_password"
pass.validator_minlength = 8
pass.maxlength = 63
pass.validator_equals_error = "Passwords do not match"

dummyvalue = access_point:option(cbi.DummyValue, "_adminpassword")
dummyvalue.template = "cbi/rawhtml"
dummyvalue.rawhtml  = true
dummyvalue.value = '<p class="note">' .. translate.translate("This password is also used in the Administration UI.") .. '</p>'


--------------------------------
-- 	functions
--------------------------------
function map.on_commit()
    sys.user.setpasswd(dispatcher.context.authuser, pass:formvalue("ap"))
    local config_name = "wireless"
    uci:load(config_name)
    uci:set(config_name, "ap", "encryption", "psk-mixed")
    uci:save(config_name)
    uci:commit(config_name)
end

return map
