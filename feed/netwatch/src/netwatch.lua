#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Monitors the network to identify changes in available networks/interfaces and modifies routing tables accordingly

local utils = require "invizboxutils"
local led = require "ledcontrol"
local uci = require("uci").cursor()
local os = require("os")
local defaultpassword = require("defaultpassword")
local signal = require("posix.signal")

local netwatch = {}
netwatch.captive = nil
netwatch.mode = nil
netwatch.mode_changed = false
netwatch.running = true
netwatch.secure = nil
netwatch.wan_up = nil

-- here for unit testing the main function by overwriting this function
function netwatch.keep_running()
    return true
end

function netwatch.check_captive_portal()
    uci:load("wizard")
    if uci:get("wizard", "main", "manual_captive_mode") == "1" then
        return true
    end
    -- make sure dnsmasq is up and running to avoid DNS timeouts
    local dnsmasq_up = false
    for _ = 1, 5 do
        dnsmasq_up = os.execute("ls /tmp/run/dnsmasq/dnsmasq.*.pid 1> /dev/null 2>&1") == 0
        if dnsmasq_up then
            break
        end
        utils.log("Waiting another second for dnsmasq to be up!")
        utils.sleep(1)
    end
    if not dnsmasq_up then
        utils.log("dnsmasq failed to come up within 5s!")
    end
    -- captive portal URL check
    if utils.s_download("https://update.invizbox.com/captive", "/tmp/captive") then
        return utils.get_first_line( "/tmp/captive") ~= "invizbox"
    end
    return true
end

function netwatch.set_dnsmasq_uci(option_name)
    utils.log("enabling the following dhcp profile: "..option_name)
    uci:load("dhcp")
    uci:set("dhcp", "captive", "disabled", "1")
    uci:set("dhcp", "auto", "disabled", "1")
    uci:set("dhcp", "tor", "disabled", "1")
    uci:set("dhcp", "vpn0", "disabled", "1")
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

function netwatch.status_and_set_captive(status, captive)
    uci:load("wizard")
    if captive then
        netwatch.captive = true
    else
        uci:set("wizard", "main", "manual_captive_mode", "0")
        netwatch.captive = false
    end
    uci:set("wizard", "main", "status", status)
    uci:save("wizard")
    uci:commit("wizard")
end

function netwatch.save_credentials()
    -- verifying credentials are saved on mtd2
    uci:load("vpn")
    local uci_username = uci:get("vpn", "active", "username")
    local uci_password = uci:get("vpn", "active", "password")
    local mtd_username, mtd_password = defaultpassword.get_vpn_credentials()
    if uci_username ~= mtd_username or uci_password ~= mtd_password then
        defaultpassword.set_vpn_credentials(uci_username, uci_password)
    end
end

function netwatch.deal_with_connectivity()
    if os.execute("ip route | grep '^default' > /dev/null") == 0 then
        if netwatch.wan_up == nil or not netwatch.wan_up then
            netwatch.wan_up = true
            utils.log("WAN interface is connected.")
            -- first check for a big time discrepancy over http (enough to enable login for openvpn - main issue)
            os.execute("htpdate -s en.wikipedia.org www.apache.org www.duckduckgo.com www.mozilla.org")
            -- then rely on ntp (if network allows - otherwise above will have to suffice)
            os.execute("/etc/init.d/sysntpd restart")
            -- Get Initial VPN server if needed
            if (not netwatch.city_1 and not netwatch.city_2 and not netwatch.city_3) then
                utils.get_nearest_cities(netwatch)
            end
        end
        return true
    end
    if netwatch.wan_up == nil or netwatch.wan_up then
        netwatch.wan_up = false
        utils.log("WAN interface is not up - going captive until this changes.")
        led.not_connected()
        netwatch.set_dnsmasq_uci("captive")
        netwatch.reset_iptables("firewall.no_network")
        netwatch.mode = "not connected"
        netwatch.secure = false
        netwatch.status_and_set_captive("No Internet Connection", false)
    end
    return false
end

function netwatch.deal_with_state()
    uci:load("vpn")
    local mode = uci:get("vpn", "active", "mode") or "none"
    netwatch.mode_changed = false
    if netwatch.mode == nil or netwatch.mode ~= mode then
        netwatch.mode = mode
        netwatch.mode_changed = true
    end
    if mode == "extend" then
        if netwatch.mode_changed then
            utils.log("Wifi extender mode - using extend configuration.")
            led.clear()
            netwatch.set_dnsmasq_uci("auto")
            netwatch.reset_iptables("firewall.extend")
            netwatch.secure = false
            netwatch.status_and_set_captive("Wifi Extender Mode (no VPN or Tor)", false)
        end
        return true
    elseif mode == "vpn" and os.execute("grep -r up /tmp/openvpn/ >/dev/null 2>&1") == 0 then
        if netwatch.mode_changed or netwatch.secure == nil or not netwatch.secure then
            utils.log("VPN mode - tun0 interface is up - using VPN configuration.")
            led.secure()
            netwatch.set_dnsmasq_uci("vpn0")
            netwatch.reset_iptables("firewall.vpn")
            netwatch.save_credentials()
            netwatch.secure = true
            netwatch.status_and_set_captive("Secure Connection - VPN Active", false)
        end
        return true
    elseif mode == "tor" and utils.tor_is_up() then
        if netwatch.mode_changed or netwatch.secure == nil or not netwatch.secure then
            utils.log("Tor mode - tor is up - using Tor configuration.")
            led.secure()
            netwatch.set_dnsmasq_uci("tor")
            netwatch.reset_iptables("firewall.tor")
            netwatch.secure = true
            netwatch.status_and_set_captive("Secure Connection - Tor Active", false)
        end
        return true
    end
    return false
end

function netwatch.deal_with_captive_portal()
    if netwatch.check_captive_portal() then
        if netwatch.captive == nil or not netwatch.captive then
            utils.log("Behind captive portal!")
            led.captive()
            netwatch.set_dnsmasq_uci("auto")
            netwatch.reset_iptables("firewall.captive")
            netwatch.mode = "captive"
            netwatch.secure = false
            netwatch.status_and_set_captive("Behind Captive Portal", true)
        end
    else
        if netwatch.mode_changed or netwatch.captive == nil or netwatch.captive
                or netwatch.secure == nil or netwatch.secure then
            uci:load("vpn")
            local mode = uci:get("vpn", "active", "mode") or "none"
            utils.log("Not behind captive portal.")
            led.connected_not_secure()
            netwatch.set_dnsmasq_uci("captive")
            netwatch.reset_iptables("firewall.no_network")
            netwatch.mode = "not captive"
            netwatch.secure = false
            if mode == "vpn" then
                netwatch.status_and_set_captive("No VPN Connection", false)
            elseif mode == "tor" then
                netwatch.status_and_set_captive("No Tor Connection", false)
            end
        end
    end
end

function netwatch.main()
    netwatch.running = true
    utils.log("Starting netwatch")
    utils.load_cities(netwatch)
    while netwatch.running do
        if netwatch.deal_with_connectivity() then
            if not netwatch.deal_with_state() then
                netwatch.deal_with_captive_portal()
            end
        end
        if netwatch.secure or netwatch.mode == "extend" then
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
