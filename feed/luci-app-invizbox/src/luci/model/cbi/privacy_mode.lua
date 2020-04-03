-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local uci = require "uci".cursor()
local translate = require "luci.i18n"
local sys = require "luci.sys"

----------------------------
--  MAP SECTION TO CONFIG FILE
------------------------------

local map = cbi.Map("vpn",translate.translate("Privacy Mode"))
map.anonymous = true

local mode_details = map:section(cbi.TypedSection, "active", "", translate.translate("Select your privacy mode:"))
mode_details.addremove = false
mode_details.anonymous = true
mode_details.isempty = true
mode_details.loop = true
mode_details.template = "cbi/tsection"

local mode = mode_details:option(cbi.ListValue, "mode", translate.translate("Choose Privacy Mode").." :" )
mode.id = "mode"
mode.widget = "radio"
mode.template = "cbi/modelvalue"
mode:value("vpn", "VPN")
mode:value("tor", "Tor")
mode:value("extend", "Wifi Extender")

function map.on_after_commit(self)
    local selected_mode = self:formvalue("cbid.vpn.active.mode")
    uci:load("wizard")
    local product_name = uci:get("wizard", "main", "product_name") or "InvizBox Go"
    if product_name == "InvizBox" then
        uci:load("tor")
        if selected_mode == "vpn" then
            uci:set("tor", "tor", "enabled", "0")
        else
            uci:set("tor", "tor", "enabled", "1")
        end
        uci:save("tor")
        uci:commit("tor")
        sys.call("/etc/init.d/tor restart")
    end
    uci:load("openvpn")
    if selected_mode == "tor" or selected_mode == "extend" then
        uci:set("openvpn", "vpn", "enabled", "0")
    else
        uci:set("openvpn", "vpn", "enabled", "1")
    end
    uci:save("openvpn")
    uci:commit("openvpn")
    sys.call("/etc/init.d/openvpn restart")
end

return map
