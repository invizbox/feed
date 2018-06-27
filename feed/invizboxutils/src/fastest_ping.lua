#! /usr/bin/env lua
-- Copyright 2018 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- finds the fastest ping server from a country or city

local uci = require("uci").cursor()

local fastest_ping = {}

function fastest_ping.overall()
    local ping_processes = {}
    uci:foreach("vpn", "server", function(section)
        if section["address"] then
            local handle = io.popen("ping -c 1 -q -s 16 -w 1 -W 1 "..section["address"].." | awk -F'/' '/avg/{print $4}'")
            ping_processes[section["name"]] = handle
        end
    end)
    local ping_speeds = {}
    local fastest_location, fast_ping
    fast_ping = 1000
    for name, handle in pairs(ping_processes) do
        ping_speeds[name] = tonumber(handle:read("*a"):sub(1, -2))
        if ping_speeds[name] and ping_speeds[name] < fast_ping then
            fastest_location = name
            fast_ping = ping_speeds[name]
        end
    end
    return fastest_location, fast_ping
end

function fastest_ping.in_country(country)
    local ping_processes = {}
    uci:foreach("vpn", "server", function(section)
        if section["address"] and section["country"] == country then
            local handle = io.popen("ping -c 1 -q -s 16 -w 1 -W 1 "..section["address"].." | awk -F'/' '/avg/{print $4}'")
            ping_processes[section["name"]] = handle
        end
    end)
    local ping_speeds = {}
    local fastest_location, fast_ping
    fast_ping = 1000
    for name, handle in pairs(ping_processes) do
        ping_speeds[name] = tonumber(handle:read("*a"):sub(1, -2))
        if ping_speeds[name] and ping_speeds[name] < fast_ping then
            fastest_location = name
            fast_ping = ping_speeds[name]
        end
    end
    return fastest_location, fast_ping
end

function fastest_ping.in_city(city)
    local ping_processes = {}
    uci:foreach("vpn", "server", function(section)
        if section["address"] and section["city"] == city then
            local handle = io.popen("ping -c 1 -q -s 16 -w 1 -W 1 "..section["address"].." | awk -F'/' '/avg/{print $4}'")
            ping_processes[section["name"]] = handle
        end
    end)
    local ping_speeds = {}
    local fastest_location, fast_ping
    fast_ping = 1000
    for name, handle in pairs(ping_processes) do
        ping_speeds[name] = tonumber(handle:read("*a"):sub(1, -2))
        if ping_speeds[name] and ping_speeds[name] < fast_ping then
            fastest_location = name
            fast_ping = ping_speeds[name]
        end
    end
    return fastest_location, fast_ping
end

if not pcall(getfenv, 4) then
    print(fastest_ping.in_country("US"))
end

return fastest_ping