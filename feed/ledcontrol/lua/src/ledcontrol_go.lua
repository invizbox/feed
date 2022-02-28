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
    uci:set("system", led_name, "trigger", "default-on")
    uci:delete("system", led_name, "delayon")
    uci:delete("system", led_name, "delayoff")
    led.uci_commit_reload()
end

function led.set_heartbeat(led_name)
    uci:load("system")
    uci:set("system", led_name, "default", "1")
    uci:set("system", led_name, "trigger", "heartbeat")
    led.uci_commit_reload()
end

function led._red_solid()
    led.set_on("red")
    led.set_off("green")
    os.execute("/etc/init.d/led reload")
    utils.log("LED going red solid")
end

function led._orange_solid()
    led.set_on("red")
    led.set_on("green")
    os.execute("/etc/init.d/led reload")
    utils.log("LED going orange solid")
end

function led._green_solid()
    led.set_off("red")
    led.set_on("green")
    os.execute("/etc/init.d/led reload")
    utils.log("LED going green solid")
end

function led._orange_flashing()
    uci:load("system")
    uci:set("system", "red", "default", "1")
    uci:set("system", "red", "trigger", "heartbeat")
    uci:set("system", "green", "default", "1")
    uci:set("system", "green", "trigger", "heartbeat")
    uci:save("system")
    uci:commit("system")
    os.execute("/etc/init.d/led reload")
    utils.log("LED going orange flashing")
end

return led
