-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- controller entry point for the basic mode
local utils = require("invizboxutils")
local fs = require("nixio.fs")
local json = require "luci.jsonc"
local basic = {}

-- luacheck: globals entry cbi _ alias node template luci call reload_wifi_networks get_wifi_networks action_logout
function basic.index()
    local uci = require("uci").cursor()
    uci:load("wizard")
    local root = node()
    if not root.lock then
        root.target = alias("basic", "basic")
        root.index = true
    end

    local page   = node("basic")
    page.sysauth = "root"
    page.order = 20
    page.sysauth_authenticator = "htmlauth"
    page.index = true
    entry({"basic", "get_wifi_networks"}, call("get_wifi_networks"), nil).leaf = true
    entry({"basic", "reload_wifi_networks"}, call("reload_wifi_networks"), nil).leaf = true

    local product_name = uci:get("wizard", "main", "product_name") or "InvizBox Go"
    local show_choose_network = product_name == "InvizBox Go"

    entry({"basic", "basic"}, template("admin_status/index"), _("Status"), 20).index = true
    entry({"basic", "invizbox"}, alias("basic", "invizbox", "vpn_location"), _(product_name), 23).index = true
    entry({"basic", "invizbox", "vpn_location"}, cbi("vpn_location"), _("VPN Location"), 1).leaf = true
    if show_choose_network then
        entry({"basic", "invizbox", "choose_network"}, cbi("choose_network", {wizard_show_prev=true}),
            _("Choose Network"), 2).leaf = true
    end
    entry({"basic", "invizbox", "privacy_mode"}, cbi("privacy_mode"), _("Privacy Mode"), 3).leaf = true
    entry({"basic", "invizbox", "hotspot"}, cbi("hotspot"), _("Hotspot"), 4).leaf = true
    entry({"basic", "invizbox", "account_details"}, cbi("account_details"), _("Account Details"), 5).leaf = true
    entry({"basic", "logout"}, call("action_logout"), _("Logout"), 90).leaf = true
    entry({"basic", "mode"}, alias("admin", "status"), _("Expert Mode"), 91).leaf = true
    local ent = entry({"wizard", "wizard"}, template("wizard"), "Wizard", 98)
    ent.dependent = false
    ent = entry({"wizard", "complete"}, template("wizard_complete"), "Wizard Complete", 99)
    ent.dependent = false
    ent.sysauth = "root"
end

function reload_wifi_networks()
    local index, networks = utils.wifi_networks()
	luci.http.prepare_content("application/json")
    local wifi_networks = {}
    for i, scanssid in ipairs(index) do
        local network = networks[scanssid]
        wifi_networks[i] = {
            ssid = scanssid,
            encryption = network.encryption,
            quality = network.quality,
        }
    end
    fs.writefile("/tmp/wifi_networks", json.stringify(wifi_networks))
    luci.http.write_json(wifi_networks)
end

function get_wifi_networks()
    if utils.file_exists("/tmp/wifi_networks") then
        local wifi_networks = json.parse(utils.get_first_line("/tmp/wifi_networks"))
        luci.http.write_json(wifi_networks)
        return
    end
    reload_wifi_networks()
end

function action_logout()
    local dsp = require "luci.dispatcher"
    local utl = require "luci.util"
    local sid = dsp.context.authsession

    if sid then
        utl.ubus("session", "destroy", { ubus_rpc_session = sid })

        luci.http.header("Set-Cookie", "sysauth=%s; expires=%s; path=%s/" %{
            sid, 'Thu, 01 Jan 1970 01:00:00 GMT', dsp.build_url()
        })
    end

    luci.http.redirect(dsp.build_url())
end

return basic
