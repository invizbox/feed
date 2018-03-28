-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local cbi = require "luci.cbi"
local translate = require "luci.i18n"
local map, account, vpnaccount, password

----------------------------
--  MAP SECTION TO CONFIG FILE
------------------------------

map = cbi.Map("vpn",translate.translate("Account Details"))
map.template = "cbi/wizardmap"
map.anonymous = true


account = map:section(cbi.NamedSection, "active", "", translate.translate("Please enter your InvizBox VPN account details below<h5 class='info-text' style='font-weight:normal;'> If the fields below are empty, your account details may have been emailed to you.</h5>"))
account.addremove = false

vpnaccount = account:option(cbi.Value, "username", translate.translate("VPN Username") .. " :" )
vpnaccount.id = "vpnaccount"
vpnaccount.placeholder = "my_identifier@invizbox"
vpnaccount.required = true
vpnaccount.validator_pattern = ".+@invizbox"
vpnaccount.template = "cbi/invizboxvalue"
vpnaccount.validator_help = "Your VPN Account username looks like this: my_identifier@invizbox"

password = account:option(cbi.Value, "password", translate.translate("VPN Password") .. " :" )
password.id = "vpnpass"
password.required = true
password.template = "cbi/invizboxvalue"
password.password = true
password.validator_minlength = 10
password.maxlength = 63

return map
