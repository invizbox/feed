#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Monitors the access point bridge and brings it back up if needed

local utils = require "invizboxutils"
local uci = require("uci").cursor()
local ubus = require("ubus")

local wifiwatch = {}
wifiwatch.running = true
wifiwatch.access_point = "ra0"
wifiwatch.station = "wan"
wifiwatch.sta_interface = "apcli0"
wifiwatch.wan_up_ds = 300
wifiwatch.failed_networks = {}

-- here for unit testing the main function by overwriting this function
function wifiwatch.keep_running()
    return true
end

function wifiwatch.last_access_to_ui()
    local connection = ubus.connect()
    if not connection then
        error("Failed to connect to ubusd")
    end
    local sessions = { connection:call("session", "list", {}) }
    local seconds_since_last_access = 3600
    for _, session in ipairs(sessions) do
        if (3600 - session["expires"]) < seconds_since_last_access then
            seconds_since_last_access = 3600 - session["expires"]
        end
    end
    return seconds_since_last_access
end

function wifiwatch.deal_with_access_point()
    local ap_interface = wifiwatch.access_point
    local access_point_available = os.execute("iw dev | grep -q ".. ap_interface) == 0
    if access_point_available then
        local access_point_up = os.execute("iw dev ".. ap_interface .." info | grep -q ssid") == 0
        if access_point_up then
            utils.log("access point interface ["..ap_interface .."] is up.")
            return 1
        else
            utils.log("access point interface ["..ap_interface .."] is not up - restarting it.")
            os.execute("ifconfig ".. ap_interface .." down")
            os.execute("ifconfig ".. ap_interface .." up")
            os.execute("/etc/init.d/dnsmasq restart")
            return 2
        end
    end
    utils.log("no access point device")
    return 3
end

function wifiwatch.restart_wan()
    os.execute("wifi down")
    for _=1,50 do
        if os.execute("ip -f inet -o addr show "..wifiwatch.sta_interface.." | grep [i]net") ~=0 then
            break
        end
        utils.sleep(.1)
    end
    os.execute("wifi up")
    for _=1,wifiwatch.wan_up_ds do
        if os.execute("ip -f inet -o addr show "..wifiwatch.sta_interface.." | grep inet") ==0 then
            return true
        end
        utils.sleep(.1)
    end
    return false
end

function wifiwatch.connect_to_wifi(ssid, encryption, key)
    local config_name = "wireless"
    uci:load(config_name)
    local section = "wan"
    uci:delete(config_name, section, "disabled")
    uci:set(config_name, section, "ssid", ssid)
    uci:set(config_name, section, "encryption", encryption)
    if encryption ~= "none" then
        uci:set(config_name, section, "key", key)
    else
        uci:delete(config_name, section, "key")
    end
    uci:commit(config_name)
    return wifiwatch.restart_wan()
end

function wifiwatch.get_nearest_vpn()
    local config_name = "vpn"
    os.execute("echo $(wget -qO- https://invizbox.com/cgi-bin/nearest) > /tmp/location.txt")
    local vpn_location = string.gmatch(utils.get_first_line("/tmp/location.txt"), "%S+")()
    local servers = {}
    local i = 1
    uci:foreach(config_name, "server", function(s)
        if uci:get(config_name, s['.name'], "country").."-"..uci:get(config_name, s['.name'], "city") == vpn_location then
            servers[i] = uci:get(config_name, s['.name'], "name")
            i = i+1
        end
    end)
    math.randomseed(os.time())
    local entry = utils.uci_characters(servers[math.random(#servers)])
    uci:set(config_name, "active", "name", entry)
    uci:commit(config_name)
end

function wifiwatch.deal_with_station(first_reboot)
    if first_reboot then
        -- prevent openvpn from connecting before we got the nearest server
        os.execute("/etc/init.d/openvpn stop")
    else
        local seconds_since_last_ui_move = wifiwatch.last_access_to_ui()
        if seconds_since_last_ui_move < 180 then
            utils.log("someone was using the UI "..seconds_since_last_ui_move.." seconds ago (<180), not scanning!")
            return 40
        end
    end
    local wan_up = os.execute(". /lib/functions/network.sh && network_flush_cache && network_is_up "..wifiwatch.station) == 0
    if wan_up then
        utils.log(wifiwatch.station.." interface is up.")
        if first_reboot then
            wifiwatch.get_nearest_vpn()
            os.execute("/etc/init.d/openvpn start")
        end
        return 10
    else
        utils.log(wifiwatch.station.." interface is not up.")
        local index, networks = utils.wifi_networks()
        local config_name = "known_networks"
        local connected = false
        uci:load(config_name)
        for _, ssid in ipairs(index) do
            local uci_ssid = utils.uci_characters(ssid)
            if uci:get(config_name, uci_ssid) == "network"
                    and uci:get(config_name, uci_ssid, "ssid") == ssid
                    and wifiwatch.failed_networks[ssid] ~= true then
                local encryption = networks[ssid].encryption
                local key = uci:get(config_name, uci_ssid, "key")
                if wifiwatch.connect_to_wifi(ssid, encryption, key) then
                    utils.log("connected to "..ssid)
                    connected = true
                    wifiwatch.failed_networks = {}
                    os.execute("/etc/init.d/vpnwatch restart")
                    break
                else
                    utils.log("unable to connect to "..ssid..", forgetting this SSID until next successful connection")
                    wifiwatch.failed_networks[ssid] = true
                end
            end
        end
        if connected and first_reboot then
            wifiwatch.get_nearest_vpn()
            os.execute("/etc/init.d/openvpn start")
        end
        if not connected then
            config_name = "wireless"
            uci:load(config_name)
            if uci:get(config_name, "wan", "disabled") ~= "1" then
                utils.log("disabling "..wifiwatch.station.." in /etc/config/wireless as no usable network found.")
                uci:set(config_name, "wan", "disabled", "1")
                uci:commit(config_name)
                os.execute("wifi up")
            end
            return 20
        end
        return 30
    end
end

function wifiwatch.main()
    wifiwatch.running=true
    local config_name = "wizard"
    local name = "main"
    local return_value = 0
    utils.log("Starting wifiwatch")

    -- wait for wizard complete + reboot to deal with networking
    uci:load(config_name)
    if uci:get(config_name, name, "complete") == "false" then
        -- fix br-ap early if needed
        wifiwatch.deal_with_access_point()

        while(wifiwatch.running) do
            utils.sleep(5)
            wifiwatch.running = wifiwatch.keep_running()
        end
        return_value = 1
    end

    -- try to reconnect to last WiFi network
    local first_reboot = uci:get(config_name, name, "firstreboot") ~= "false"
    if not first_reboot then
        for _=1,wifiwatch.wan_up_ds do
            if os.execute("ip -f inet -o addr show "..wifiwatch.sta_interface.." | grep inet") ==0 then
                break
            end
            utils.sleep(.1)
        end
    end

    -- normal running loop
    local station_scan_counter = 0
    while(wifiwatch.running) do
        if station_scan_counter
        return_value = wifiwatch.deal_with_station(first_reboot)
        return_value = return_value + wifiwatch.deal_with_access_point()
        if first_reboot then
            uci:set(config_name, name, "firstreboot", "false")
            uci:save(config_name)
            uci:commit(config_name)
            first_reboot = false
        end
        utils.sleep(180)
        wifiwatch.running = wifiwatch.keep_running()
    end
    utils.log("Stopping wifiwatch")
    return return_value
end

if not pcall(getfenv, 4) then
    wifiwatch.main()
end

return wifiwatch
