-- Copyright 2020 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local translate = require "luci.i18n"

local map = cbi.Map("wizard",translate.translate("Captive Portal"))
map.anonymous = true
map:chain("vpn")

local hide_checkbox = "1"
local show_activate_button = "0"
local section_heading = translate.translate("No captive portal has been detected.")
local help_text = translate.translate("If you believe your VPN has not connected due to a captive portal, you can"..
        " temporarily allow all traffic through.")
local status = map.uci:get("wizard", "main", "status")
if status == "No Internet Connection" then
    section_heading = translate.translate("Captive portals are not detected while there is no Internet connection.")
elseif status == "Wifi Extender Mode (no VPN or Tor)" then
    section_heading = translate.translate("Captive portals are not detected in WiFi Extender mode.")
elseif status == "Behind Captive Portal" and map.uci:get("wizard", "main", "manual_captive_mode") ~= "1" then
    section_heading = translate.translate("A captive portal has been detected.")
    show_activate_button = "1"
elseif status == "Behind Captive Portal" or status == "No VPN Connection" or status == "No Tor Connection" then
    if map.uci:get("vpn", "active", "mode") == "tor" then
        help_text = translate.translate("If you believe Tor has not connected due to a captive portal, you can"..
                " temporarily allow all traffic through.")
    end
    hide_checkbox = "0"
end

local section = map:section(cbi.NamedSection, "main", "wizard", "", section_heading)
section.addremove = false
section.anonymous = true

local hide_checkbox_input = section:option(cbi.DummyValue, "hide_checkbox")
hide_checkbox_input.template = "cbi/hiddeninput"
hide_checkbox_input.id = "hide-checkbox"
hide_checkbox_input.value = hide_checkbox

local show_button_input = section:option(cbi.DummyValue, "show_activate_button")
show_button_input.template = "cbi/hiddeninput"
show_button_input.id = "show-button"
show_button_input.value = show_activate_button

section:option(cbi.Flag, "manual_captive_mode", translate.translate("Allow all traffic (non-secure)")..":",
    help_text)

return map
