#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Deals with the colour and state of the WiFi LED

local uci = require("uci").cursor()
local utils = require "invizboxutils"

local led = {}
led.config="system"

function led.get_leds()
    local leds = {}
    uci:load(led.config)
    uci:foreach(led.config, "led", function(s)
        table.insert(leds, s['.name'])
    end)
    return leds[1], leds[2]
end

function led.set_solid(self)
    uci:load(led.config)
    uci:set(led.config, self, "default", "1")
    uci:set(led.config, self, "trigger", "default-on")
    uci:save(led.config)
    uci:commit(led.config)
end

function led.set_flashing(self)
    uci:load(led.config)
    uci:set(led.config, self, "default", "1")
    uci:set(led.config, self, "trigger", "heartbeat")
    uci:save(led.config)
    uci:commit(led.config)
end

function led.set_off(self)
    uci:load(led.config)
    uci:set(led.config, self, "default", "0")
    uci:set(led.config, self, "trigger", "none")
    uci:save(led.config)
    uci:commit(led.config)
end

function led._red_solid()
    local green, red = led.get_leds()
    led.set_solid(red)
    led.set_off(green)
    os.execute("/etc/init.d/led reload")
end

function led._orange_solid()
    local green, red = led.get_leds()
    led.set_solid(red)
    led.set_solid(green)
    os.execute("/etc/init.d/led reload")
end

function led._green_solid()
    local green, red = led.get_leds()
    led.set_off(red)
    led.set_solid(green)
    os.execute("/etc/init.d/led reload")
end

function led._red_flashing()
    local green, red = led.get_leds()
    led.set_flashing(red)
    led.set_off(green)
    os.execute("/etc/init.d/led reload")
end

function led._orange_flashing()
    local green, red = led.get_leds()
    uci:load(led.config)
    uci:set(led.config, red, "default", "1")
    uci:set(led.config, red, "trigger", "heartbeat")
    uci:set(led.config, green, "default", "1")
    uci:set(led.config, green, "trigger", "heartbeat")
    uci:save(led.config)
    uci:commit(led.config)
    os.execute("/etc/init.d/led reload")
end

function led._green_flashing()
    local green, red = led.get_leds()
    led.set_off(red)
    led.set_flashing(green)
    os.execute("/etc/init.d/led reload")
end

function led._red_green_flashing()
    local green, red = led.get_leds()
    led.set_solid(red)
    led.set_flashing(green)
    os.execute("/etc/init.d/led reload")
end

function led.not_connected()
    led._red_solid()
    utils.log("LED going red solid")
end

function led.captive()
    led._orange_solid()
    utils.log("LED going orange solid")
end

function led.connected_not_secure()
    led._orange_flashing()
    utils.log("LED going orange flashing")
end

function led.secure()
    led._green_solid()
    utils.log("LED going green solid")
end

function led.clear()
    led._orange_solid()
    utils.log("LED going orange solid")
end

function led.error()
    led._red_green_flashing()
    utils.log("LED going red/green flashing")
end

return led
