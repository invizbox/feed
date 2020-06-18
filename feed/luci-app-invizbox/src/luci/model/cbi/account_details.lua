-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local translate = require "luci.i18n"
local dispatcher = require "luci.dispatcher"
local fs = require "nixio.fs"
local http = require "luci.http"
local sys = require "luci.sys"
local map, account, vpnaccount, password, wizard_prev_page

map = cbi.Map("vpn", translate.translate("Account Details"))
map.anonymous = true
map:chain("wizard")
if map.uci:get("wizard", "main", "complete") == "false" then
    map.redirect = dispatcher.build_url("basic", "invizbox", "choose_network")
end

local enter_string = "Enter your InvizBox VPN account details below"
account = map:section(cbi.NamedSection, "active", "", "", translate.translate(enter_string))
account.addremove = false

vpnaccount = account:option(cbi.Value, "username", translate.translate("VPN Username").." :" )
vpnaccount.id = "vpnaccount"
vpnaccount.placeholder = "my_identifier"
vpnaccount.required = true
vpnaccount.template = "cbi/value"

password = account:option(cbi.Value, "password", translate.translate("VPN Password").." :" )
password.id = "vpnpass"
password.required = true
password.template = "cbi/value"
password.password = true
password.maxlength = 63

if map.uci:get("wizard", "main", "complete") == "false" then
    wizard_prev_page = account:option(cbi.DummyValue, "wizard_prev_page")
    wizard_prev_page.template = "cbi/hiddeninput"
    wizard_prev_page.id = "wizard_prev_page"
    wizard_prev_page.value = dispatcher.build_url("wizard", "wizard")

    function map.on_after_save()
        http.redirect(dispatcher.build_url("basic", "invizbox", "choose_network"))
    end
end

function map.on_after_commit(self)
    fs.writefile("/etc/openvpn/login.auth", self:formvalue("cbid.vpn.active.username").."\n"..
            self:formvalue("cbid.vpn.active.password"))
    sys.call("/etc/init.d/openvpn restart")
end

return map
