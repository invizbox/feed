#! /usr/bin/env lua
-- Copyright 2021 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local utils = require("invizboxutils")
local led_original = require("ledcontrol_original")
local led_go = require("ledcontrol_go")
local led_2 = require("ledcontrol_2")

local led = {}

function led.init()
    led.model = utils.get_hardware_model()
    if led.model == "InvizBox 2" then
        led_2._info_off()
    end
end

function led.not_connected()
    if led.model == "InvizBox" then
        led_original._blue_off()
    elseif led.model == "InvizBox Go" then
        led_go._red_solid()
    elseif led.model == "InvizBox 2" then
        led_2._globe_off()
        led_2._lock_off()
    end
end

function led.connected()
    if led.model == "InvizBox 2" then
        led_2._globe_on()
    end
end

function led.vpn_connected()
    if led.model == "InvizBox" then
        led_original._blue_solid()
    elseif led.model == "InvizBox Go" then
        led_go._green_solid()
    elseif led.model == "InvizBox 2" then
        led_2._lock_on()
    end
end

function led.vpn_not_connected()
    if led.model == "InvizBox" then
        led_original._blue_flashing()
    elseif led.model == "InvizBox Go" then
        led_go._orange_flashing()
    elseif led.model == "InvizBox 2" then
        led_2._lock_off()
    end
end

function led.new_firmware()
    if led.model == "InvizBox 2" then
        led_2._info_slow_flashing()
    end
end

function led.captive()
    if led.model == "InvizBox" then
        led_original._blue_quick_flashing()
    elseif led.model == "InvizBox Go" then
        led_go._orange_solid()
    elseif led.model == "InvizBox 2" then
        led_2._info_slow_flashing()
    end
end

function led.no_vpn_network()
    if led.model == "InvizBox" then
        led_original._blue_flashing()
    elseif led.model == "InvizBox Go" then
        led_go._orange_solid()
    elseif led.model == "InvizBox 2" then
        led_2._lock_off()
    end
end

return led
