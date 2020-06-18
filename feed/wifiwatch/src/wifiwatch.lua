#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Monitors the access point bridge and brings it back up if needed

local utils = require "invizboxutils"
local uci = require("uci").cursor()
local ubus = require("ubus")
local signal = require("posix.signal")

local wifiwatch = {}
wifiwatch.running = true
wifiwatch.wan_interface = "eth0.2"
wifiwatch.wan_up_ds = 30
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

function wifiwatch.restart_wan()
    os.execute("wifi down")
    for _=1, 5 do
        if os.execute("ip -f inet -o addr show "..wifiwatch.wan_interface.." 2>/dev/null | grep [i]net") ~=0 then
            break
        end
        utils.sleep(1)
    end
    os.execute("wifi up")
    for _=1, wifiwatch.wan_up_ds do
        if os.execute("ip -f inet -o addr show "..wifiwatch.wan_interface.." 2>/dev/null | grep inet") ==0 then
            return true
        end
        utils.sleep(1)
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

function wifiwatch.deal_with_station()
    if os.execute("ip route | grep '^default' > /dev/null") == 0 then
        utils.log(wifiwatch.wan_interface.." interface is up.")
        return 10
    else
        utils.log(wifiwatch.wan_interface.." interface is not up.")
        local seconds_since_last_ui_move = wifiwatch.last_access_to_ui()
        local config_name = "known_networks"
        uci:load(config_name)
        local connected = false
        if seconds_since_last_ui_move >= 180 then
            if uci:foreach(config_name, "network", function(network)
                return wifiwatch.failed_networks[network.ssid] and wifiwatch.failed_networks[network.ssid] < 3
            end) then
                utils.log("Trying to connect to known servers")
                local index, networks = utils.wifi_networks()
                for _, ssid in ipairs(index) do
                    local uci_ssid = utils.uci_characters(ssid)
                    local failed_to_connect = wifiwatch.failed_networks[ssid] and wifiwatch.failed_networks[ssid] >= 3
                    if uci:get(config_name, uci_ssid) == "network"
                            and uci:get(config_name, uci_ssid, "ssid") == ssid
                            and not failed_to_connect then
                        local encryption = networks[ssid].encryption
                        local key = uci:get(config_name, uci_ssid, "key")
                        if wifiwatch.connect_to_wifi(ssid, encryption, key) then
                            utils.log("connected to "..ssid)
                            connected = true
                            wifiwatch.failed_networks = {}
                            os.execute("/etc/init.d/openvpn restart")
                            break
                        else
                            utils.log("unable to connect to SSID ["..ssid.."], removing one attempt to connect from 3")
                            if wifiwatch.failed_networks[ssid] == nil then
                                wifiwatch.failed_networks[ssid] = 1
                            else
                                wifiwatch.failed_networks[ssid] = wifiwatch.failed_networks[ssid] + 1
                            end
                        end
                    end
                end
            end
        else
            utils.log("someone was using the UI "..seconds_since_last_ui_move.." seconds ago (<180), not scanning!")
        end
        if not connected then
            config_name = "wireless"
            uci:load(config_name)
            if uci:get(config_name, "wan", "disabled") ~= "1" then
                utils.log("disabling "..wifiwatch.wan_interface.." in /etc/config/wireless as no usable network found.")
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
    utils.log("Starting wifiwatch")

    -- wait to give a chance to the existing entry to (re)connect
    for _=1, wifiwatch.wan_up_ds do
        if os.execute("ip -f inet -o addr show "..wifiwatch.wan_interface.." 2>/dev/null | grep inet") ==0 then
            break
        end
        utils.sleep(1)
    end

    while(wifiwatch.running) do
        wifiwatch.deal_with_station()
        for _=1, 30 do
            utils.sleep(1)
        end
        wifiwatch.running = wifiwatch.keep_running()
    end
    utils.log("Stopping wifiwatch")
end

signal.signal(signal.SIGTERM, function()
  os.exit(20)
end)

if not pcall(getfenv, 4) then
    wifiwatch.main()
    os.exit(0)
end

return wifiwatch
