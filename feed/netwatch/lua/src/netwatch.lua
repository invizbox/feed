#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Monitors the network to identify changes in available networks/interfaces and modifies routing tables accordingly

local utils = require("invizboxutils")
local led = require("ledcontrol")
local uci = require("uci").cursor()
local os = require("os")
local credentials = require("credentials")
local signal = require("posix.signal")

local netwatch = {}
netwatch.running = true
netwatch.state = nil

-- here for unit testing the main function by overwriting this function
function netwatch.keep_running()
    return true
end

function netwatch.set_dnsmasq_uci(option_name)
    utils.log("enabling the following dhcp profile: "..option_name)
    uci:load("dhcp")
    uci:set("dhcp", "captive", "disabled", "1")
    uci:set("dhcp", "auto", "disabled", "1")
    uci:set("dhcp", "tor", "disabled", "1")
    uci:set("dhcp", "vpn1", "disabled", "1")
    uci:set("dhcp", option_name, "disabled", "0")
    uci:set("dhcp", "lan", "instance", option_name)
    uci:save("dhcp")
    uci:commit("dhcp")
    os.execute("/etc/init.d/dnsmasq reload")
end

function netwatch.reset_iptables(firewall_script)
    utils.log("enabling the following firewall include: "..firewall_script)
    uci:load("firewall")
    uci:set("firewall", "user_include", "path", "/bin/"..firewall_script)
    uci:save("firewall")
    uci:commit("firewall")
    os.execute("/etc/init.d/firewall reload")
end

function netwatch.save_credentials()
    -- verifying credentials are saved on mtd2
    uci:load("vpn")
    local uci_openvpn_usr = uci:get("vpn", "active", "username") or ""
    local uci_openvpn_pass = uci:get("vpn", "active", "password") or ""
    local uci_plan = uci:get("vpn", "active", "plan") or ""
    local provider_id = uci:get("vpn", "active", "provider") or "unknown"
    local uci_ipsec_usr = ""
    local uci_ipsec_pass = ""
    if provider_id == "expressvpn" or provider_id == "windscribe" then
        uci_ipsec_usr = uci:get("ipsec", "vpn_1", "eap_identity") or ""
        uci_ipsec_pass = uci:get("ipsec", "vpn_1", "eap_password") or ""
    end
    local _, openvpn_usr, openvpn_pass, ipsec_usr, ipsec_pass, plan, _ = credentials.get_vpn_credentials()
    if uci_openvpn_usr ~= openvpn_usr or uci_openvpn_pass ~= openvpn_pass
            or uci_ipsec_usr ~= ipsec_usr or uci_ipsec_pass ~= ipsec_pass
            or uci_plan ~= plan then
        credentials.set_vpn_credentials(uci_openvpn_usr, uci_openvpn_pass, uci_ipsec_usr, uci_ipsec_pass, uci_plan)
    end
end

function netwatch.handle_state()
    uci:load("vpn")
    local mode = uci:get("vpn", "active", "mode") or "none"
    if os.execute("ip route | grep '^default' > /dev/null") == 0 then
        if netwatch.state == "not connected" then
            utils.log("WAN interface is connected.")
            -- force date jump
            os.execute("/etc/init.d/sysntpd restart")
            -- Get Initial VPN server if needed
            if (not netwatch.city_1 and not netwatch.city_2 and not netwatch.city_3) then
                utils.get_nearest_cities(netwatch)
            end
        end
    else
        if netwatch.state ~= "not connected" then
            utils.log("WAN interface is not up - going captive until this changes.")
            netwatch.state = "not connected"
            led.not_connected()
            netwatch.set_dnsmasq_uci("captive")
            netwatch.reset_iptables("firewall.no_network")
        end
        return false
    end
    if mode == "extend" then
        if netwatch.state ~= "extend" then
            utils.log("Wifi extender mode - using extend configuration.")
            netwatch.state = "extend"
            led.no_vpn_network()
            netwatch.set_dnsmasq_uci("auto")
            netwatch.reset_iptables("firewall.extend")
        end
        return true
    end
    if mode == "vpn" and os.execute("grep -r up /tmp/openvpn/ >/dev/null 2>&1") == 0 then
        if netwatch.state ~= "vpn" then
            utils.log("VPN mode - tun1 interface is up - using VPN configuration.")
            netwatch.state = "vpn"
            led.vpn_connected()
            netwatch.set_dnsmasq_uci("vpn1")
            netwatch.reset_iptables("firewall.vpn")
            netwatch.save_credentials()
        end
        return true
    end
    if mode == "tor" and utils.tor_is_up() then
        if netwatch.state ~= "tor" then
            utils.log("Tor mode - tor is up - using Tor configuration.")
            netwatch.state = "tor"
            led.vpn_connected()
            netwatch.set_dnsmasq_uci("tor")
            netwatch.reset_iptables("firewall.tor")
        end
        return true
    end
    if netwatch.state ~= "no network" then
        utils.log("No network.")
        netwatch.state = "no network"
        led.vpn_not_connected()
        netwatch.set_dnsmasq_uci("captive")
        netwatch.reset_iptables("firewall.no_network")
    end
    return false
end

function netwatch.main()
    netwatch.running = true
    utils.log("Starting netwatch")
    led.init()
    utils.load_cities(netwatch)
    while netwatch.running do
        if netwatch.handle_state() then
            utils.sleep(10)
        else
            utils.sleep(2)
        end
        netwatch.running = netwatch.keep_running()
    end
    utils.log("Stopping netwatch")
end

signal.signal(signal.SIGTERM, function()
  os.exit(20)
end)

if not pcall(getfenv, 4) then
    netwatch.main()
    os.exit(0)
end

return netwatch
