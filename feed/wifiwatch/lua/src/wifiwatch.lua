#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Monitors the access point bridge and brings it back up if needed

local utils = require("invizboxutils")
local uci = require("uci").cursor()
local signal = require("posix.signal")
local time = require('posix.time')

local wifiwatch = {}
wifiwatch.running = true
wifiwatch.wan_up_ds = 30
wifiwatch.wan_up = nil
wifiwatch.station_sleep = 30
wifiwatch.failed_networks = {}

-- here for unit testing the main function by overwriting this function
function wifiwatch.keep_running()
    return true
end

function wifiwatch.last_access_to_ui()
    local now = os.time(os.date('!*t'))
    os.execute("tail -n 1 /var/log/lighttpd/api.log | cut -d [ -f 2 | cut -d ] -f 1 > /tmp/last_api_access.txt")
    local log_timestamp = utils.get_first_line("/tmp/last_api_access.txt") or ""
    local log_date = time.strptime(log_timestamp, "%d/%b/%Y:%H:%M:%S")
    local log_time = now - 181
    if log_date then
        log_time = os.time({
            year=1900+log_date.tm_year,
            month=log_date.tm_mon+1,
            day=log_date.tm_mday,
            hour=log_date.tm_hour - tonumber(log_timestamp:sub(22,24)),
            min=log_date.tm_min + tonumber(log_timestamp:sub(25,26)),
            sec=log_date.tm_sec,
            isdst=false})
    end
    return now - log_time
end

function wifiwatch.restart_wan()
    os.execute("wifi down")
    for _=1, 5 do
        if os.execute("ip route | grep '^default' > /dev/null") ~= 0 then
            break
        end
        utils.sleep(1)
    end
    os.execute("wifi up")
    for _=1, wifiwatch.wan_up_ds do
        if os.execute("ip route | grep '^default' > /dev/null") == 0 then
            return true
        end
        utils.sleep(1)
    end
    return false
end

function wifiwatch.connect_to_wifi(ssid, encryption, key)
    uci:load("wireless")
    uci:set("wireless", "wan", "mode", "sta")
    uci:set("wireless", "wan", "ssid", ssid)
    uci:set("wireless", "wan", "encryption", encryption)
    if encryption ~= "none" then
        uci:set("wireless", "wan", "key", key)
    else
        uci:delete("wireless", "wan", "key")
    end
    uci:commit("wireless")
    os.execute("sync")
    os.execute("kill -USR1 $(ps | grep [r]est_api | awk '{print $1}') 2>/dev/null")
    return wifiwatch.restart_wan()
end

function wifiwatch.deal_with_station()
    if os.execute("ip route | grep '^default' > /dev/null") == 0 then
        if wifiwatch.wan_up == nil or not wifiwatch.wan_up then
            utils.log("WAN interface is up.")
            wifiwatch.wan_up = true
        end
        return 10
    else
        if wifiwatch.wan_up == nil or wifiwatch.wan_up then
            utils.log("WAN interface is down.")
            wifiwatch.wan_up = false
        end
        uci:load("known_networks")
        local connected = false
        local seconds_since_last_ui_move = wifiwatch.last_access_to_ui()
        local known_network_keys = {}
        if seconds_since_last_ui_move >= 60 then
            if uci:foreach("known_networks", "network", function(network)
                known_network_keys[network.ssid] = network.key or ""
                return wifiwatch.failed_networks[network.ssid] and wifiwatch.failed_networks[network.ssid] < 3
            end) then
                utils.log("Trying to connect to known servers")
                local index, networks = utils.wifi_networks()
                for _, ssid in ipairs(index) do
                    local failed_to_connect = wifiwatch.failed_networks[ssid] and wifiwatch.failed_networks[ssid] >= 3
                    if known_network_keys[ssid] ~= nil and not failed_to_connect then
                        local encryption = networks[ssid].encryption
                        if wifiwatch.connect_to_wifi(ssid, encryption, known_network_keys[ssid]) then
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
            uci:load("wireless")
            if uci:get("wireless", "wan", "mode") ~= "scan" then
                utils.log("switching WAN to scanning mode.")
                uci:set("wireless", "wan", "mode", "scan")
                uci:commit("wireless")
                os.execute("sync")
                os.execute("wifi")
            end
            return 20
        end
        return 30
    end
end

function wifiwatch.main()
    wifiwatch.running=true
    utils.log("Starting wifiwatch")

    -- wait to give a chance to the existing entry to (re)connect if in sta mode
    uci:load("wireless")
    if uci:get("wireless", "wan", "mode") == "sta" then
        for _=1, wifiwatch.wan_up_ds do
            if os.execute("ip route | grep '^default' > /dev/null") == 0 then
                break
            end
            utils.sleep(1)
        end
    end

    while(wifiwatch.running) do
        wifiwatch.deal_with_station()
        for _=1, wifiwatch.station_sleep do
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
