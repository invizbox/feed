#! /usr/bin/env lua
-- Copyright 2018 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- handles mtd persisted information

local utils = require("invizboxutils")
local os = require("os")

local credentials = {}

function credentials.get_model_pwd_length()
    local model = utils.get_hardware_model()
    local password_length = 0
    if model == "InvizBox" then
        password_length = 14
    elseif model == "InvizBox Go" then
        password_length = 16
    end
    return model, password_length
end

function credentials.get_vpn_credentials()
    local wifi_pass, provider_id, vpn_credentials, ipsec_credentials
    local openvpn_usr, openvpn_pass, plan, ipsec_usr, ipsec_pass = "", "", "", "", ""
    local model, pwd_length = credentials.get_model_pwd_length()
    if model == "InvizBox 2" then
        provider_id = utils.get_first_line("/private/provider.txt")
        wifi_pass = utils.get_first_line("/private/wifi_password.txt")
        vpn_credentials = utils.get_first_line("/private/vpn_credentials.txt")
        local counter = 1
        for word in vpn_credentials:gmatch('([^ ]+)') do
            if counter == 1 then
                openvpn_usr = word
            elseif counter == 2 then
                openvpn_pass = word
            elseif counter == 3 then
                plan = word
            end
            counter = counter + 1
        end
        ipsec_credentials = utils.get_first_line("/private/ipsec_credentials.txt")
        counter = 1
        for word in ipsec_credentials:gmatch('([^ ]+)') do
            if counter == 1 then
                ipsec_usr = word
            elseif counter == 2 then
                ipsec_pass = word
            end
            counter = counter + 1
        end
    else
        provider_id = utils.run_and_log("dd if=/dev/mtd2 bs=1 skip="..tostring(65536-pwd_length-24-64-24-64-20-20)
                .." count=20 2>/dev/null")
        plan = utils.run_and_log("dd if=/dev/mtd2 bs=1 skip="..tostring(65536-pwd_length-24-64-24-64-20)
                .." count=20 2>/dev/null")
        ipsec_usr = utils.run_and_log("dd if=/dev/mtd2 bs=1 skip="..tostring(65536-pwd_length-24-64-24-64)
                .." count=64 2>/dev/null")
        ipsec_pass = utils.run_and_log("dd if=/dev/mtd2 bs=1 skip="..tostring(65536-pwd_length-24-64-24)
                .." count=24 2>/dev/null")
        openvpn_usr = utils.run_and_log("dd if=/dev/mtd2 bs=1 skip="..tostring(65536-pwd_length-24-64)
                .." count=64 2>/dev/null")
        openvpn_pass = utils.run_and_log("dd if=/dev/mtd2 bs=1 skip="..tostring(65536-pwd_length-24)
                .." count=24 2>/dev/null")
        wifi_pass = utils.run_and_log("dd if=/dev/mtd2 bs=1 skip="..tostring(65536-pwd_length)
                .." count="..tostring(pwd_length).." 2>/dev/null")
    end
    return wifi_pass:gsub("%s*$", ""),
    openvpn_usr:gsub("%s*$", ""), openvpn_pass:gsub("%s*$", ""),
    ipsec_usr:gsub("%s*$", ""), ipsec_pass:gsub("%s*$", ""),
    plan:gsub("%s*$", ""), provider_id:gsub("%s*$", "")
end

function credentials.set_vpn_credentials(openvpn_usr, openvpn_pass, ipsec_usr, ipsec_pass, plan)
    local model, pwd_length = credentials.get_model_pwd_length()
    if model == "InvizBox 2" then
        if os.execute("echo '"..openvpn_usr.." "..openvpn_pass.." "..plan.."' > /tmp/vpn_credentials.txt") == 0 then
            os.execute("! diff -q /tmp/vpn_credentials.txt /private/vpn_credentials.txt"..
                    "&& cp /tmp/vpn_credentials.txt /private/vpn_credentials.txt")
        end
        if ipsec_usr ~= "" and ipsec_pass ~= "" then
            if os.execute('echo "'..ipsec_usr..' '..ipsec_pass..'" > /tmp/ipsec_credentials.txt') == 0 then
                os.execute("! diff -q /tmp/ipsec_credentials.txt /private/ipsec_credentials.txt"..
                        "&& cp /tmp/ipsec_credentials.txt /private/ipsec_credentials.txt")
            end
        else
            os.execute("rm /private/ipsec_credentials.txt")
        end
    else
        os.execute(". /bin/invizboxutils.sh; write_string_to_mtd2 '"..openvpn_pass.."' 24 "
                ..tostring(65536-pwd_length-24))
        os.execute(". /bin/invizboxutils.sh; write_string_to_mtd2 '"..openvpn_usr.."' 64 "
                ..tostring(65536-pwd_length-24-64))
        os.execute(". /bin/invizboxutils.sh; write_string_to_mtd2 '"..ipsec_pass.."' 24 "
                ..tostring(65536-pwd_length-24-64-24))
        os.execute(". /bin/invizboxutils.sh; write_string_to_mtd2 '"..ipsec_usr.."' 64 "
                ..tostring(65536-pwd_length-24-64-24-64))
        os.execute(". /bin/invizboxutils.sh; write_string_to_mtd2 '"..plan.."' 20 "
                ..tostring(65536-pwd_length-24-64-24-64-20))
    end
end

if not pcall(getfenv, 4) then
    local wifi, openvpn_usr, openvpn_pass, ipsec_usr, ipsec_pass, plan, provider = credentials.get_vpn_credentials()
    print("WiFi password: "..wifi)
    if ipsec_usr then
        print("OpenVPN credentials: '"..openvpn_usr.."' - '"..openvpn_pass.."'")
        print("IKEv2 credentials: '"..ipsec_usr.."' - '"..ipsec_pass.."'")
    end
        print("VPN credentials: '"..openvpn_usr.."' - '"..openvpn_pass.."'")
    print("VPN provider:"..provider)
    if plan then
        print("VPN plan: "..plan)
    end
end

return credentials
