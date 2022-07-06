#! /usr/bin/env lua
-- Copyright 2018 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Monitors the network to identify changes in available networks/interfaces and modifies routing tables accordingly

local led = require("ledcontrol")
local credentials = require("credentials")
local os = require("os")
local signal = require("posix.signal")
local string = require("string")
local uci_mod = require("uci")
local uci = uci_mod.cursor()
local update = require("update")
local utils = require("invizboxutils")

local netwatch2 = {}
netwatch2.running = true
netwatch2.state = nil
netwatch2.update_ready = false

-- here for unit testing the main function by overwriting this function
function netwatch2.keep_running()
    return true
end

function netwatch2.vpn_enabled()
    for vpn_interface, _ in pairs(utils.get_vpn_interfaces()) do
        uci:load("openvpn")
        uci:load("ipsec")
        uci:load("wireguard")
        if uci:get("openvpn", vpn_interface, "enabled") == "1"
                or uci:get("ipsec", vpn_interface, "enabled") == "1"
                or uci:get("wireguard", vpn_interface, "enabled") == "1" then
            return true
        end
    end
    return false
end

function netwatch2.check_captive_portal()
    -- make sure dnsmasq is up and running to avoid DNS timeouts
    local dnsmasq_up = false
    for _ = 1, 5 do
        dnsmasq_up = os.execute("ls /tmp/run/dnsmasq/dnsmasq.invizbox.pid 1> /dev/null 2>&1") == 0
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
    if utils.s_download("https://update.invizbox.com/captive", "/tmp/captive", 10) then
        return utils.get_first_line("/tmp/captive") ~= "invizbox"
    end
    return true
end

function netwatch2.set_dnsmasq_uci_captive(captive)
    if captive then
        utils.log("making the invizbox dnsmasq captive.")
        if netwatch2.model == "InvizBox 2" then
            uci:set("dhcp", "vpn1", "address", {"/#/10.154.0.1"})
            uci:set("dhcp", "vpn2", "address", {"/#/10.154.1.1"})
            uci:set("dhcp", "vpn3", "address", {"/#/10.154.2.1"})
            uci:set("dhcp", "vpn4", "address", {"/#/10.154.3.1"})
            uci:set("dhcp", "tor", "address", {"/#/10.154.4.1"})
            uci:set("dhcp", "clear1", "address", {"/#/10.154.5.1"})
            uci:set("dhcp", "clear2", "address", {"/#/10.154.6.1"})
        elseif netwatch2.model == "InvizBox Go" then
            uci:set("dhcp", "vpn1", "address", {"/#/10.153.146.1"})
            uci:set("dhcp", "tor", "address", {"/#/10.153.147.1"})
            uci:set("dhcp", "clear1", "address", {"/#/10.153.148.1"})
        end
    else
        utils.log("making the invizbox dnsmasq not captive")
        if netwatch2.model == "InvizBox 2" then
            uci:delete("dhcp", "vpn1", "address")
            uci:delete("dhcp", "vpn2", "address")
            uci:delete("dhcp", "vpn3", "address")
            uci:delete("dhcp", "vpn4", "address")
            uci:delete("dhcp", "tor", "address")
            uci:delete("dhcp", "clear1", "address")
            uci:delete("dhcp", "clear2", "address")
        elseif netwatch2.model == "InvizBox Go" then
            uci:delete("dhcp", "vpn1", "address")
            uci:delete("dhcp", "tor", "address")
            uci:delete("dhcp", "clear1", "address")
        end
    end
    uci:save("dhcp")
    uci:commit("dhcp")
    os.execute("sync")
    os.execute("kill -USR1 $(ps | grep [r]est_api | awk '{print $1}') 2>/dev/null")
    os.execute("/etc/init.d/dnsmasq reload")
end

function netwatch2.should_check_if_captive(loop_count)
    uci:load("dhcp")
    if netwatch2.model ~= "InvizBox Go" then
        return false
    elseif netwatch2.state == "captive" then
        return true
    elseif loop_count % 5 ~= 0 then
        return false
    elseif netwatch2.vpn_enabled() then
        return os.execute("grep -r up /tmp/openvpn/ >/dev/null 2>&1") ~= 0
    elseif uci:get("dhcp", "lan_tor", "disabled") ~= "1" then
        local tor_up = utils.tor_is_up()
        return not tor_up, tor_up
    end
    return loop_count % 30 == 0
end

function netwatch2.deal_with_connectivity(loop_count)
    if os.execute("ip route | grep '^default' > /dev/null") == 0 then
        if netwatch2.state == "not connected" or netwatch2.state == nil then
            utils.log("wan interface is connected.")
            -- LED
            led.connected()
            -- force date jump
            os.execute("/etc/init.d/sysntpd restart")
            -- DNS
            netwatch2.set_dnsmasq_uci_captive(false)
        end
        -- Get Initial VPN server if needed
        if (not netwatch2.city_1 and not netwatch2.city_2 and not netwatch2.city_3) then
            utils.get_nearest_cities(netwatch2)
        end
        local check_portal, tor_up = netwatch2.should_check_if_captive(loop_count)
        if check_portal then
            if netwatch2.check_captive_portal() then
                if netwatch2.state ~= "captive" then
                    utils.log("Behind captive portal. Allowing traffic to login to captive portal.")
                    led.captive()
                    os.execute("./bin/set_captive.ash")
                    netwatch2.state = "captive"
                end
                return
            elseif netwatch2.state == "captive" then
                utils.log("No longer behind captive portal. Undoing captive changes.")
                os.execute("./bin/unset_captive.ash")
            end
        end
        -- now deal with VPN connectivity
        if netwatch2.vpn_enabled() then
            if os.execute("grep -r up /tmp/openvpn/ >/dev/null 2>&1") == 0 then
                if netwatch2.state ~= "vpn connected" then
                    netwatch2.save_credentials()
                    led.vpn_connected()
                    netwatch2.state = "vpn connected"
                end
            else
                if netwatch2.state ~= "vpn not connected" then
                    led.vpn_not_connected()
                    netwatch2.state = "vpn not connected"
                end
            end
        else
            if netwatch2.state ~= "no vpn" then
                led.no_vpn_network()
                netwatch2.state = "no vpn"
            end
        end
        uci:load("vpn")
        uci:load("update")
        local current_vpn_sha = uci:get("update", "active", "current_vpn_sha") or ""
        if tor_up == nil then
            tor_up = utils.tor_is_up()
        end
        if uci:get("vpn", "active", "username") ~= nil and current_vpn_sha == "" and tor_up then
            utils.log("Running update to get the initial set of VPN configurations")
            if os.execute("lock -n /var/lock/update.lock") == 0 then
                pcall(update.load_configuration)
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
        if netwatch2.state == "captive" then
            utils.log("No longer behind captive portal. Undoing captive changes.")
            os.execute("./bin/unset_captive.ash")
        end
        if netwatch2.state ~= "not connected" then
            netwatch2.state = "not connected"
            utils.log("wan interface is not connected.")
            -- attempt to force a tor disconnect
            if utils.tor_is_up() then
                os.execute("/etc/init.d/tor restart")
            end
            -- LED
            led.not_connected()
            -- DNS
            netwatch2.set_dnsmasq_uci_captive(true)
        end
    end
end

function netwatch2.save_credentials()
    -- check if things are identical to private and if the correct type has connected, persist if needed
    local save_credentials = false
    uci:load("vpn")
    local uci_plan = uci:get("vpn", "active", "plan") or ""
    local uci_openvpn_usr = uci:get("vpn", "active", "username") or ""
    os.execute("sed '2!d' /etc/openvpn/login.auth > /tmp/vpn_password.txt")
    local uci_openvpn_pass = utils.get_first_line("/tmp/vpn_password.txt")
    local provider_id = uci:get("vpn", "active", "provider") or "unknown"
    local uci_ipsec_usr = ""
    local uci_ipsec_pass = ""
    if provider_id == "expressvpn" or provider_id == "windscribe" then
        uci:load("ipsec")
        uci_ipsec_usr = uci:get("ipsec", "vpn_1", "eap_identity") or ""
        uci_ipsec_pass = uci:get("ipsec", "vpn_1", "eap_password") or ""
    end
    for vpn_interface, _ in pairs(utils.get_vpn_interfaces()) do
        local network_id = string.sub(vpn_interface, 5, 5)
        local net_up = utils.get_first_line("/tmp/openvpn/"..network_id.."/status") == "up"
        if net_up and not save_credentials then
            save_credentials = true
            local _, openvpn_usr, openvpn_pass, ipsec_usr, ipsec_pass, plan, _ = credentials.get_vpn_credentials()
            if uci_openvpn_usr ~= openvpn_usr or uci_openvpn_pass ~= openvpn_pass
                    or uci_ipsec_usr ~= ipsec_usr or uci_ipsec_pass ~= ipsec_pass
                    or uci_plan ~= plan then
                credentials.set_vpn_credentials(uci_openvpn_usr, uci_openvpn_pass, uci_ipsec_usr, uci_ipsec_pass,
                        uci_plan)

            end
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
    if not netwatch2.update_ready then
        uci:load("update")
        if uci:get("update", "version", "new_firmware") ~= nil then
            netwatch2.update_ready = true
            led.new_firmware()
        end
    end
end

function netwatch2.main()
    netwatch2.running = true
    utils.log("Starting netwatch2")
    netwatch2.model = utils.get_hardware_model()
    led.init()
    utils.load_cities(netwatch2)
    local loop_count = 0
    while netwatch2.running do
        if netwatch2.model == "InvizBox 2" then
            netwatch2.deal_with_swconfig("eth0.2", "0") -- WAN
            netwatch2.deal_with_swconfig("eth0.1", "1") -- LAN
        end
        netwatch2.deal_with_update()
        netwatch2.deal_with_connectivity(loop_count)
        utils.sleep(2)
        netwatch2.running = netwatch2.keep_running()
        loop_count = (loop_count + 1) % 30
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
