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

local map, access_point, ssid, pass, dummyvalue, hidden, isolate

map = cbi.Map("wireless", translate.translate("Hotspot"))
map.anonymous = true

uci:load("wizard")
local product_name = uci:get("wizard", "main", "product_name") or "InvizBox Go"

access_point = map:section(cbi.NamedSection, "lan", "wifi-iface", "", translate.translate("Name the "..product_name..
        " Wifi Hotspot"))
access_point.addremove = false

ssid = access_point:option(cbi.Value, "ssid", translate.translate("Hotspot Name") )
ssid.required = true
ssid.maxlength = 63
ssid.template = "cbi/value"

pass = access_point:option(cbi.Value, "key", translate.translate("Hotspot Password"))
pass.template = "cbi/password"
pass.password = true
pass.required = true
pass.id = "hotspot_password"
pass.validator_equals = "#hotspot_password"
pass.validator_minlength = 8
pass.maxlength = 63
pass.validator_equals_error = "Passwords do not match"

dummyvalue = access_point:option(cbi.DummyValue, "_adminpassword")
dummyvalue.template = "cbi/dvalue"
dummyvalue.rawhtml  = true
dummyvalue.value = '<p class="note">'..translate.translate("This password is also used in the Administration UI.")..
        '</p>'

hidden = access_point:option(cbi.Flag, "hidden", translate.translate("Hidden SSID"))
hidden.template = "cbi/flag"

isolate = access_point:option(cbi.Flag, "isolate", translate.translate("Wireless Isolation"))
isolate.template = "cbi/flag"

--------------------------------
-- 	functions
--------------------------------
function map.on_commit()
    sys.user.setpasswd(dispatcher.context.authuser, pass:formvalue("lan"))
    local config_name = "wireless"
    uci:load(config_name)
    uci:set(config_name, "lan", "encryption", "psk-mixed")
    uci:save(config_name)
    uci:commit(config_name)
end

function map.on_after_commit()
    sys.call("/etc/init.d/openvpn restart")
end

return map
