-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local translate = require "luci.i18n"
local dispatcher = require "luci.dispatcher"
local fs = require "nixio.fs"
local sys = require "luci.sys"
local map, account, vpnaccount, password

map = cbi.Map("vpn", translate.translate("Account Details"))
map.anonymous = true
map:chain("wizard")
if map.uci:get("wizard", "main", "complete") == "false" then
    map.redirect = dispatcher.build_url("wizard/complete")
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

function map.on_after_commit(self)
    fs.writefile("/etc/openvpn/login.auth", self:formvalue("cbid.vpn.active.username").."\n"..
            self:formvalue("cbid.vpn.active.password"))
    sys.call("/etc/init.d/openvpn restart")
end

return map
