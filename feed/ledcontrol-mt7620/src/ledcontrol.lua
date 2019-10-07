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
    uci:set(led.config, self, "default", "0")
    uci:set(led.config, self, "trigger", "none")
    uci:save(led.config)
    uci:commit(led.config)
end

function led.set_flashing(self)
    uci:load(led.config)
    uci:set(led.config, self, "default", "1")
    uci:set(led.config, self, "trigger", "timer")
    uci:set(led.config, self, "delayon", "250")
    uci:set(led.config, self, "delayoff", "250")
    uci:save(led.config)
    uci:commit(led.config)
end

function led.set_quick_flashing(self)
    uci:load(led.config)
    uci:set(led.config, self, "default", "1")
    uci:set(led.config, self, "trigger", "timer")
    uci:set(led.config, self, "delayon", "100")
    uci:set(led.config, self, "delayoff", "500")
    uci:save(led.config)
    uci:commit(led.config)
end

function led.set_off(self)
    uci:load(led.config)
    uci:set(led.config, self, "default", "1")
    uci:set(led.config, self, "trigger", "none")
    uci:save(led.config)
    uci:commit(led.config)
end

function led._blue_solid()
    led.set_solid("blue")
    os.execute("/etc/init.d/led reload")
end

function led._blue_flashing()
    led.set_flashing("blue")
    os.execute("/etc/init.d/led reload")
end

function led._blue_quick_flashing()
    led.set_quick_flashing("blue")
    os.execute("/etc/init.d/led reload")
end

function led._blue_off()
    led.set_off("blue")
    os.execute("/etc/init.d/led reload")
end

function led.not_connected()
    led._blue_off()
    utils.log("LED going off")
end

function led.captive()
    led._blue_quick_flashing()
    utils.log("LED going quick blue flashing")
end

function led.connected_not_secure()
    led._blue_flashing()
    utils.log("LED going normal blue flashing")
end

function led.secure()
    led._blue_solid()
    utils.log("LED going blue solid")
end

function led.clear()
    led._blue_flashing()
    utils.log("LED going normal blue flashing")
end

function led.error()
    led._blue_quick_flashing()
    utils.log("LED going quick blue flashing")
end

return led
