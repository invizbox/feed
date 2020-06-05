#! /usr/bin/env lua
-- Copyright 2018 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Monitors the network to identify changes in available networks/interfaces and modifies routing tables accordingly

local led = require "ledcontrol"
local os = require("os")
local signal = require("posix.signal")
local string = require("string")
local uci_mod = require("uci")
local uci = uci_mod.cursor()
local update = require("update")
local utils = require "invizboxutils"

local netwatch2 = {}
netwatch2.running = true
netwatch2.wan_up = nil
netwatch2.vpn_connected = nil
netwatch2.wan_interface = "eth0.2"
netwatch2.lan_interface = "eth0.1"

-- here for unit testing the main function by overwriting this function
function netwatch2.keep_running()
    return true
end

function netwatch2.set_dnsmasq_uci_captive(captive)
    local config_name = "dhcp"
    if captive then
        utils.log("making the invizbox dnsmasq captive.")
        uci:set(config_name, "vpn1", "address", {"/#/10.154.0.1"})
        uci:set(config_name, "vpn2", "address", {"/#/10.154.1.1"})
        uci:set(config_name, "vpn3", "address", {"/#/10.154.2.1"})
        uci:set(config_name, "vpn4", "address", {"/#/10.154.3.1"})
        uci:set(config_name, "tor", "address", {"/#/10.154.4.1"})
        uci:set(config_name, "clear1", "address", {"/#/10.154.5.1"})
        uci:set(config_name, "clear2", "address", {"/#/10.154.6.1"})
    else
        utils.log("making the invizbox dnsmasq not captive")
        uci:delete(config_name, "vpn1", "address")
        uci:delete(config_name, "vpn2", "address")
        uci:delete(config_name, "vpn3", "address")
        uci:delete(config_name, "vpn4", "address")
        uci:delete(config_name, "tor", "address")
        uci:delete(config_name, "clear1", "address")
        uci:delete(config_name, "clear2", "address")
    end
    uci:save(config_name)
    uci:commit(config_name)
    os.execute("kill -USR1 $(ps | grep [r]est_api | awk '{print $1}') 2>/dev/null")
    os.execute("/etc/init.d/dnsmasq reload")
end

function netwatch2.deal_with_connectivity()
    if os.execute("ip route | grep '^default' > /dev/null") == 0 then
        if netwatch2.wan_up == nil or not netwatch2.wan_up then
            netwatch2.wan_up = true
            utils.log(netwatch2.wan_interface.." interface is connected.")
            -- Get Initial VPN server if needed
            if (not netwatch2.city_1 and not netwatch2.city_2 and not netwatch2.city_3) then
                utils.get_nearest_cities(netwatch2)
            end
            -- LED
            led._globe_on()
            -- time update
            os.execute("/etc/init.d/sysntpd restart")
            -- DNS
            netwatch2.set_dnsmasq_uci_captive(false)
        end
        uci:load("vpn")
        uci:load("update")
        if uci:get("vpn", "active", "username") ~= nil and uci:get("update", "active", "current_vpn_sha") == "123456"
                and utils.tor_is_up() then
            utils.log("Running update to get the initial set of VPN configurations")
            if os.execute("lock -n /var/lock/update.lock") == 0 then
                pcall(update.load_update_config)
                local success, return_value = pcall(update.update_vpn)
                if success and return_value == true then
                    os.execute("kill -USR1 $(ps | grep [r]est_api | awk '{print $1}') 2>/dev/null")
                else
                    utils.log("Error updating VPN locations")
                end
                os.execute("lock -u /var/lock/update.lock")
            end
        end
    else
        if netwatch2.wan_up == nil or netwatch2.wan_up then
            netwatch2.wan_up = false
            utils.log(netwatch2.wan_interface.." interface is not connected.")
            -- LED
            led._globe_off()
            -- DNS
            netwatch2.set_dnsmasq_uci_captive(true)
        end
    end
end

function netwatch2.save_credentials()
    -- check if things are identical to private and if the correct type has connected, persist if needed
    local save_openvpn, save_ipsec = false, false
    uci:load("admin-interface")
    uci:load("vpn")
    local separate_ipsec_credentials = uci:get("admin-interface", "features", "separate_ipsec_credentials") == "true"
    uci:foreach("admin-interface", "network", function(network)
        if string.sub(network[".name"], 1, 7) == "lan_vpn" then
            local openvpn_net = uci:get("vpn", network["protocol_id"], "vpn_protocol") == "OpenVPN"
            local ikev2_net = uci:get("vpn", network["protocol_id"], "vpn_protocol") == "IKEv2"
            local network_id = string.sub(network[".name"], 8)
            local net_up = utils.get_first_line("/tmp/openvpn/"..network_id.."/status") == "up"
            if openvpn_net and net_up and not save_openvpn then
                save_openvpn = true
                if os.execute("sed 'N;s/\\n/ /' /etc/openvpn/login.auth > /tmp/vpn_credentials.txt") == 0 then
                    os.execute("! diff -q /tmp/vpn_credentials.txt /private/vpn_credentials.txt"..
                            "&& cp /tmp/vpn_credentials.txt /private/vpn_credentials.txt")
                end
            elseif separate_ipsec_credentials and ikev2_net and net_up and not save_ipsec then
                save_ipsec = true
                uci:load("ipsec")
                local ipsec_username = uci:get("ipsec", "vpn_"..network_id, "eap_identity")
                local ipsec_password = uci:get("ipsec", "vpn_"..network_id, "eap_password")
                if ipsec_username and ipsec_password then
                    os.execute('echo "'..ipsec_username..' '..ipsec_password..'" > /tmp/ipsec_credentials.txt')
                    os.execute("! diff -q /tmp/ipsec_credentials.txt /private/ipsec_credentials.txt"..
                            "&& cp /tmp/ipsec_credentials.txt /private/ipsec_credentials.txt")
                end
            end
        end
    end)
end

function netwatch2.deal_with_vpn()
    if netwatch2.wan_up and os.execute("grep -r up /tmp/openvpn/ >/dev/null 2>&1") == 0 then
        netwatch2.save_credentials()
        if netwatch2.vpn_connected == nil or not netwatch2.vpn_connected then
            led._lock_on()
            netwatch2.vpn_connected = true
        end
    else
        if netwatch2.vpn_connected == nil or netwatch2.vpn_connected then
            led._lock_off()
            netwatch2.vpn_connected = false
        end
    end
end

function netwatch2.deal_with_swconfig(interface, port)
    local switch_up = os.execute("swconfig dev switch0 port "..port.." get link 2>/dev/null | grep -q link:up") == 0
    local link_up = os.execute("ip link show "..interface.." 2>/dev/null | grep -q 'state UP'") == 0
    if switch_up and not link_up then
        os.execute("ip link set "..interface.." up 2>/dev/null")
    elseif not switch_up and link_up then
        os.execute("ip link set "..interface.." down 2>/dev/null")
    end
end

function netwatch2.deal_with_update()
    uci:load("update")
    if uci:get("update", "version", "new_firmware") ~= nil then
        led._info_slow_flashing()
    end
end

function netwatch2.main()
    netwatch2.running = true
    utils.log("Starting netwatch2")
    led._info_off()
    utils.load_cities(netwatch2)
    while netwatch2.running do
        netwatch2.deal_with_swconfig(netwatch2.wan_interface, "0")
        netwatch2.deal_with_swconfig(netwatch2.lan_interface, "1")
        netwatch2.deal_with_vpn()
        netwatch2.deal_with_update()
        netwatch2.deal_with_connectivity()
        utils.sleep(2)
        netwatch2.running = netwatch2.keep_running()
    end
    utils.log("Stopping netwatch2")
end

signal.signal(signal.SIGTERM, function()
  os.exit(20)
end)

if not pcall(getfenv, 4) then
    netwatch2.main()
    os.exit(0)
end

return netwatch2
