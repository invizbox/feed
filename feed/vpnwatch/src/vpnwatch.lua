#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Monitors the vpn config file to identify changes in active vpn setting and propagate to openvpn

local utils = require "invizboxutils"
local uci = require("uci").cursor()

local vpnwatch = {}
vpnwatch.vpn_list = {}
vpnwatch.running = true

-- here for unit testing the main function by overwriting this function
function vpnwatch.keep_running()
    return true
end

function vpnwatch.do_nothing()
    while vpnwatch.running do
        utils.sleep(10)
        vpnwatch.running = vpnwatch.keep_running()
    end
end

function vpnwatch.setup_auth()
    local current_username, current_password
    local auth_file = io.open("/etc/openvpn/login.auth", "r")
    if auth_file then
        current_username = auth_file:read()
        current_password = auth_file:read()
        auth_file:close()
    end
    local config_name = "vpn"
    uci:load(config_name)
    local section = "active"
    local username = uci:get(config_name, section, "username")
    local password = uci:get(config_name, section, "password")
    if auth_file == nil or password ~= current_password or username ~= current_username then
        auth_file = io.open("/etc/openvpn/login.auth", "w")
        auth_file:write(username.."\n"..password)
        auth_file:close()
        utils.log("Updated the active VPN credentials - restarting openvpn is needed")
        return true
    else
        utils.log("current VPN credentials are already in use, no change")
        return false
    end
end

function vpnwatch.setup_config(vpn_interface, tun_name)
    local config_name = "vpn"
    uci:load(config_name)
    local selected_server = uci:get(config_name, "active", vpn_interface) or uci:get(config_name, "active", "name")
    local tmp_filename = "/tmp/open"..vpn_interface..".conf"
    local final_filename = "/etc/openvpn/open"..vpn_interface..".conf"
    if uci:get(config_name, selected_server) == "server" then
        if uci:get(config_name, selected_server, "template") then
            local template = uci:get(config_name, selected_server, "template")
            local address = uci:get(config_name, selected_server, "address")
            os.execute('sed "s/@SERVER_ADDRESS@/'..address..'/; s/@TUN@/'..tun_name..'/" '..template..' > '..tmp_filename)
        elseif uci:get(config_name, selected_server, "filename") then
            local non_template_filename = uci:get(config_name, selected_server, "filename")
            os.execute('sed "s/@TUN@/'..tun_name..'/" '..non_template_filename..' > '..tmp_filename)
        end
        if os.execute("diff "..tmp_filename.." "..final_filename)~=0 and
                os.execute("cp "..tmp_filename.." "..final_filename) == 0 then
            utils.log(selected_server .." is now the current active VPN config - restarting openvpn is needed")
            return true
        else
            utils.log("current VPN config is already in use, no change")
            return false, 2
        end
    else
        utils.log("config marked as active is not available in config, no change")
        return false, 3
    end
end

function vpnwatch.main()
    vpnwatch.running=true
    utils.log("Starting vpnwatch")
    local config_name = "vpn"
    uci:load(config_name)
    local mode = uci:get(config_name, "active", "mode")
    if mode == "tor" or mode == "extend" then
        utils.log(mode.." mode - disabling openvpn")
        os.execute("/etc/init.d/openvpn stop")
        os.execute("/etc/init.d/openvpn disable")
    else -- either vpn mode or no mode
        utils.log("VPN required - enabling openvpn")
        os.execute("/etc/init.d/openvpn enable")
        local restart_needed = false
        vpnwatch.vpn_list = utils.get_vpn_interfaces()
        for vpn_interface, tun_name in pairs(vpnwatch.vpn_list) do
            restart_needed = vpnwatch.setup_config(vpn_interface, tun_name) or restart_needed
        end
        restart_needed = vpnwatch.setup_auth() or restart_needed
        if restart_needed then
            os.execute("/etc/init.d/openvpn restart")
        else
            os.execute("/etc/init.d/openvpn start")
        end
    end
    vpnwatch.do_nothing()
    utils.log("Stopping vpnwatch")
    return 0
end

if not pcall(getfenv, 4) then
    vpnwatch.main()
end

return vpnwatch
