#! /usr/bin/env lua
-- Copyright 2018 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Script to store devices when seen for a new dhcp lease
--
-- this will be called by dnsmasq everytime a new device is connected with the following arguments
-- arg[1] = add | old | del
-- arg[2] = mac address
-- arg[3] = ip address
-- arg[4] = device name

local utils = require "invizboxutils"
local uci = require("uci").cursor()

local function add_device(section_name, mac_address, ip_address, name)
    local config_name = "devices"
    uci:load(config_name)
    uci:set(config_name, section_name, "device")
    uci:set(config_name, section_name, "mac_address", mac_address)
    uci:set(config_name, section_name, "ip_address", ip_address)
    local previous_device_name = uci:get(config_name, section_name, "name")
    if previous_device_name == nil or previous_device_name == "" then
        uci:set(config_name, section_name, "name", name)
    end
    uci:set(config_name, section_name, "hostname", name)
    uci:save(config_name)
    uci:commit(config_name)
end

local function remove_ip(section_name)
    local config_name = "devices"
    uci:load(config_name)
    uci:delete(config_name, section_name, "ip_address")
    uci:save(config_name)
    uci:commit(config_name)
end

local mac_address = utils.uci_characters(arg[2]) or ""
if mac_address ~= nil then
    if arg[1] == "add" or arg[1] == "old" then
        add_device(mac_address, arg[2], arg[3], arg[4] or "")
        utils.log("Adding/updating MAC address in dnsmasq : ["..arg[2].."]")
    elseif arg[1] == "del" then
        remove_ip(mac_address)
        utils.log("Removing IP address for MAC : ["..arg[2].."]")
    end
end
