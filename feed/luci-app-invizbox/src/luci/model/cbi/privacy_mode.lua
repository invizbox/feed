-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local translate = require "luci.i18n"
local sys = require "luci.sys"

local map = cbi.Map("vpn",translate.translate("Privacy Mode"))
map.anonymous = true
map:chain("wizard")
map:chain("tor")
map:chain("openvpn")

local mode_details = map:section(cbi.NamedSection, "active", "active", "",
        translate.translate("Select your privacy mode:"))
mode_details.addremove = false
mode_details.anonymous = true

local mode = mode_details:option(cbi.ListValue, "mode", translate.translate("Choose Privacy Mode").." :" )
mode.id = "mode"
mode.widget = "radio"
mode.template = "cbi/modelvalue"
mode:value("vpn", "VPN")
mode:value("tor", "Tor")
mode:value("extend", "Wifi Extender")

function map.on_after_commit(self)
    local selected_mode = self:formvalue("cbid.vpn.active.mode")
    local product_name = map.uci:get("wizard", "main", "product_name") or "InvizBox Go"
    if product_name == "InvizBox" then
        if selected_mode == "vpn" then
            map.uci:set("tor", "tor", "enabled", "0")
        else
            map.uci:set("tor", "tor", "enabled", "1")
        end
        map.uci:save("tor")
        map.uci:commit("tor")
        sys.call("/etc/init.d/tor restart")
    end
    if selected_mode == "tor" or selected_mode == "extend" then
        map.uci:set("openvpn", "vpn_0", "enabled", "0")
    else
        map.uci:set("openvpn", "vpn_0", "enabled", "1")
    end
    map.uci:save("openvpn")
    map.uci:commit("openvpn")
    sys.call("/etc/init.d/openvpn restart")
end

return map
