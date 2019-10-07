#! /usr/bin/env lua
-- Copyright 2018 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Monitors the network to identify changes in available networks/interfaces and modifies routing tables accordingly

local utils = require "invizboxutils"
local led = require "ledcontrol"
local uci_mod = require("uci")
local uci = uci_mod.cursor()
local uci_rom = uci_mod.cursor("/rom/etc/config")
local signal = require("posix.signal")

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
        uci:delete(config_name, "vpn1", "server")
        uci:delete(config_name, "vpn1", "serversfile")
        uci:set(config_name, "vpn1", "address", {"/#/10.154.0.1"})

        uci:delete(config_name, "vpn2", "server")
        uci:delete(config_name, "vpn2", "serversfile")
        uci:set(config_name, "vpn2", "address", {"/#/10.154.1.1"})

        uci:delete(config_name, "vpn3", "server")
        uci:delete(config_name, "vpn3", "serversfile")
        uci:set(config_name, "vpn3", "address", {"/#/10.154.2.1"})

        uci:delete(config_name, "vpn4", "server")
        uci:delete(config_name, "vpn4", "serversfile")
        uci:set(config_name, "vpn4", "address", {"/#/10.154.3.1"})

        uci:delete(config_name, "tor", "server")
        uci:delete(config_name, "tor", "serversfile")
        uci:set(config_name, "tor", "address", {"/#/10.154.4.1"})

        uci:delete(config_name, "clear1", "resolvfile")
        uci:delete(config_name, "clear1", "serversfile")
        uci:set(config_name, "clear1", "noresolv", "1")
        uci:set(config_name, "clear1", "address", {"/#/10.154.5.1"})

        uci:delete(config_name, "clear2", "resolvfile")
        uci:delete(config_name, "clear2", "serversfile")
        uci:set(config_name, "clear2", "noresolv", "1")
        uci:set(config_name, "clear2", "address", {"/#/10.154.6.1"})
    else
        utils.log("making the invizbox dnsmasq not captive")
        uci_rom:load(config_name)
        local dns_server_1 = uci_rom:get(config_name, "vpn1", "server")[1]
        local dns_server_2 = uci_rom:get(config_name, "vpn1", "server")[2]
        dns_server_1 = string.match(dns_server_1, "(.*)@") or dns_server_1
        dns_server_2 = string.match(dns_server_2, "(.*)@") or dns_server_2
        uci:delete(config_name, "vpn1", "address")
        uci:set(config_name, "vpn1", "server", {dns_server_1.."@tun1", dns_server_2.."@tun1"})
        uci:set(config_name, "vpn1", "serversfile", "/etc/dns_blacklist/lan_vpn1.overall")

        uci:delete(config_name, "vpn2", "address")
        uci:set(config_name, "vpn2", "server", {dns_server_1.."@tun2", dns_server_2.."@tun2"})
        uci:set(config_name, "vpn2", "serversfile", "/etc/dns_blacklist/lan_vpn2.overall")

        uci:delete(config_name, "vpn3", "address")
        uci:set(config_name, "vpn3", "server", {dns_server_1.."@tun3", dns_server_2.."@tun3"})
        uci:set(config_name, "vpn3", "serversfile", "/etc/dns_blacklist/lan_vpn3.overall")

        uci:delete(config_name, "vpn4", "address")
        uci:set(config_name, "vpn4", "server", {dns_server_1.."@tun4", dns_server_2.."@tun4"})
        uci:set(config_name, "vpn4", "serversfile", "/etc/dns_blacklist/lan_vpn4.overall")

        uci:delete(config_name, "tor", "address")
        uci:set(config_name, "tor", "server", {"172.31.1.1#9053"})
        uci:set(config_name, "tor", "serversfile", "/etc/dns_blacklist/lan_tor.overall")

        uci:delete(config_name, "clear1", "address")
        uci:delete(config_name, "clear1", "noresolv")
        uci:set(config_name, "clear1", "resolvfile", "/tmp/resolv.conf.auto")
        uci:set(config_name, "clear1", "serversfile", "/etc/dns_blacklist/lan_clear1.overall")

        uci:delete(config_name, "clear2", "address")
        uci:delete(config_name, "clear2", "noresolv")
        uci:set(config_name, "clear2", "resolvfile", "/tmp/resolv.conf.auto")
        uci:set(config_name, "clear2", "serversfile", "/etc/dns_blacklist/lan_clear2.overall")
    end
    uci:save(config_name)
    uci:commit(config_name)
    os.execute("kill -USR1 $(ps | grep [r]est_api | awk '{print $1}') 2>/dev/null")
    os.execute("/etc/init.d/dnsmasq reload")
end

function netwatch2.deal_with_connectivity()
    if os.execute("ip -f inet -o addr show "..netwatch2.wan_interface.." | grep [i]net > /dev/null") == 0 then
        if netwatch2.wan_up == nil or not netwatch2.wan_up then
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
            netwatch2.wan_up = true
        end
    else
        if netwatch2.wan_up == nil or netwatch2.wan_up then
            utils.log(netwatch2.wan_interface.." interface is not connected.")
            -- LED
            led._globe_off()
            -- DNS
            netwatch2.set_dnsmasq_uci_captive(true)
            netwatch2.wan_up = false
        end
    end
end

function netwatch2.deal_with_vpn()
    if os.execute("grep -r up /tmp/openvpn/ >/dev/null 2>&1") == 0 then
        if netwatch2.vpn_connected == nil or not netwatch2.vpn_connected then
            led._lock_on()
            netwatch2.vpn_connected = true
            -- verifying credentials are saved on /private
            os.execute("sed 'N;s/\\n/ /' /etc/openvpn/login.auth > /tmp/vpn_credentials.txt")
            os.execute("! diff -q /tmp/vpn_credentials.txt /private/vpn_credentials.txt"..
                    "&& cp /tmp/vpn_credentials.txt /private/vpn_credentials.txt")
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
    local config_name = "update"
    uci:load(config_name)
    if uci:get(config_name, "version", "new_firmware") ~= nil then
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
