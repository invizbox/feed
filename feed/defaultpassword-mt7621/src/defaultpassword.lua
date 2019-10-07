#! /usr/bin/env lua
-- Copyright 2018 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- handles mtd persisted password and vpn credentials

local utils = require "invizboxutils"

local default_password = {}

function default_password.get_vpn_credentials()
    local username = utils.run_and_log("dd if=/dev/mtd2 bs=1 skip=65432 count=64 2>/dev/null")
    local password = utils.run_and_log("dd if=/dev/mtd2 bs=1 skip=65496 count=24 2>/dev/null")
    return username:gsub("%s*$", ""), password:gsub("%s*$", "")
end

function default_password.get_wifi_password()
    return utils.run_and_log("dd if=/dev/mtd2 bs=1 skip=65520 count=16 2>/dev/null")
end

function default_password.set_vpn_credentials(username, password)
    local result = os.execute(". /bin/mtdutils.sh; write_string_to_mtd2 '"..username.."' 64 65432")
    local result2 = os.execute(". /bin/mtdutils.sh; write_string_to_mtd2 '"..password.."' 24 65496")
    return result, result2
end

function default_password.set_wifi_password(password)
    return os.execute(". /bin/mtdutils.sh; write_string_to_mtd2 '"..password.."' 16 65520")
end

if not pcall(getfenv, 4) then
    print("WiFi password: "..default_password.get_wifi_password())
    local username, password = default_password.get_vpn_credentials()
    print("VPN credentials: "..username.." - "..password)
end

return default_password
