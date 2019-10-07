#! /usr/bin/env lua
-- Copyright 2019 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Deals with the colour and state of the info LED

local uci = require("uci").cursor()
local utils = require "invizboxutils"

local led = {}
led.config="system"

function led.uci_commit_reload()
    uci:save(led.config)
    uci:commit(led.config)
    os.execute("rm /var/run/led.state") -- avoid flash
    os.execute("/etc/init.d/led reload")
end

function led.set_off(led_name)
    uci:load(led.config)
    uci:set(led.config, led_name, "default", "0")
    uci:set(led.config, led_name, "trigger", "none")
    uci:delete(led.config, led_name, "delayon")
    uci:delete(led.config, led_name, "delayoff")
    led.uci_commit_reload()
end

function led.set_heartbeat(led_name)
    uci:load(led.config)
    uci:set(led.config, led_name, "trigger", "heartbeat")
    led.uci_commit_reload()
end

function led.set_slow_flashing(led_name)
    uci:load(led.config)
    uci:set(led.config, led_name, "trigger", "timer")
    uci:set(led.config, led_name, "delayon", "100")
    uci:set(led.config, led_name, "delayoff", "5000")
    led.uci_commit_reload()
end

function led.set_quick_flashing(led_name)
    uci:load(led.config)
    uci:set(led.config, led_name, "trigger", "timer")
    uci:set(led.config, led_name, "delayon", "100")
    uci:set(led.config, led_name, "delayoff", "500")
    led.uci_commit_reload()
end

function led.set_on(led_name)
    uci:load(led.config)
    uci:set(led.config, led_name, "trigger", "default-on")
    led.uci_commit_reload()
end

function led._lock_off()
    led.set_off("led_lock")
    utils.log("lock LED going off")
end

function led._lock_heartbeat()
    led.set_heartbeat("led_lock")
    utils.log("lock LED flashing")
end

function led._lock_quick_flashing()
    led.set_quick_flashing("led_lock")
    utils.log("lock LED flashing quickly")
end

function led._lock_on()
    led.set_on("led_lock")
    utils.log("lock LED going green")
end

function led._globe_off()
    led.set_off("led_globe")
    utils.log("globe LED going red")
end

function led._globe_heartbeat()
    led.set_heartbeat("led_globe")
    utils.log("globe LED flashing")
end

function led._globe_quick_flashing()
    led.set_quick_flashing("led_globe")
    utils.log("globe LED flashing quickly")
end

function led._globe_on()
    led.set_on("led_globe")
    utils.log("globe LED going green")
end

function led._info_off()
    led.set_off("led_info")
    utils.log("info LED going off")
end

function led._info_heartbeat()
    led.set_heartbeat("led_info")
    utils.log("info LED flashing")
end

function led._info_slow_flashing()
    led.set_slow_flashing("led_info")
    utils.log("info LED flashing slowly")
end

function led._info_quick_flashing()
    led.set_quick_flashing("led_info")
    utils.log("info LED flashing quickly")
end

function led._info_on()
    led.set_on("led_info")
    utils.log("info LED going green")
end

return led
