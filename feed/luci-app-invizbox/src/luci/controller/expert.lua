-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- controller entry point for the expert Mode - additions to admin
local expert = {}

-- luacheck: globals entry cbi _ alias call luci action_logout
function expert.index()
    local uci = require("uci").cursor()
    local product_name = uci:get("wizard", "main", "product_name") or "InvizBox Go"
    local show_choose_network = product_name == "InvizBox Go"

    entry({"admin", "invizbox"}, alias("admin", "invizbox", "hotspot"), _(product_name), 23).index = true
    entry({"admin", "invizbox", "vpn_location"}, cbi("vpn_location"), _("VPN Location"), 1).leaf = true
    if show_choose_network then
        entry({"admin", "invizbox", "choose_network"}, cbi("choose_network"), _("Choose Network"), 2).leaf = true
        entry({"admin", "invizbox", "captive_portal"}, cbi("captive_portal"), _("Captive Portal"), 8).leaf = true
    end
    entry({"admin", "invizbox", "privacy_mode"}, cbi("privacy_mode"), _("Privacy Mode"), 3).leaf = true
    entry({"admin", "invizbox", "hotspot"}, cbi("hotspot"), _("Hotspot"), 4).leaf = true
    entry({"admin", "invizbox", "dns"}, cbi("dns"), _("DNS"), 4).leaf = true
    entry({"admin", "invizbox", "account_details"}, cbi("account_details"), _("Account Details"), 5).leaf = true
    entry({"admin", "invizbox", "tor_configuration"}, cbi("tor_configuration"), _("Tor Configuration"), 6).leaf = true
    entry({"admin", "invizbox", "tor_advanced"}, cbi("tor_advanced"), _("Tor Advanced"), 7).leaf = true
    entry({"admin", "logout"}, call("action_logout"), _("Logout"), 90).leaf = true
    entry({"admin", "mode"}, alias("basic", "basic"), _("Basic Mode"), 91).leaf = true
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

return expert
