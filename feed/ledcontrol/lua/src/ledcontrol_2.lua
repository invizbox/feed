#! /usr/bin/env lua
-- Copyright 2021 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local uci = require("uci").cursor()
local utils = require("invizboxutils")

local led = {}

function led.uci_commit_reload()
    uci:save("system")
    uci:commit("system")
    os.execute("rm /var/run/led.state") -- avoid flash
    os.execute("/etc/init.d/led reload")
end

function led.set_off(led_name)
    uci:load("system")
    uci:set("system", led_name, "default", "0")
    uci:set("system", led_name, "trigger", "none")
    uci:delete("system", led_name, "delayon")
    uci:delete("system", led_name, "delayoff")
    led.uci_commit_reload()
end

function led.set_on(led_name)
    uci:load("system")
    uci:set("system", led_name, "default", "1")
    uci:set("system", led_name, "trigger", "none")
    uci:delete("system", led_name, "delayon")
    uci:delete("system", led_name, "delayoff")
    led.uci_commit_reload()
end

function led.set_slow_flashing(led_name)
    uci:load("system")
    uci:set("system", led_name, "trigger", "timer")
    uci:set("system", led_name, "delayon", "100")
    uci:set("system", led_name, "delayoff", "5000")
    led.uci_commit_reload()
end

function led._lock_off()
    led.set_off("led_lock")
    utils.log("lock LED going off")
end

function led._lock_on()
    led.set_on("led_lock")
    utils.log("lock LED going green")
end

function led._globe_off()
    led.set_off("led_globe")
    utils.log("globe LED going red")
end

function led._globe_on()
    led.set_on("led_globe")
    utils.log("globe LED going green")
end

function led._info_off()
    led.set_off("led_info")
    utils.log("info LED going off")
end

function led._info_slow_flashing()
    led.set_slow_flashing("led_info")
    utils.log("info LED flashing slowly")
end

return led
