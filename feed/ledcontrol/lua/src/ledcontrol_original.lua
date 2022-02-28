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

function led.set_off(self)
    uci:load("system")
    uci:set("system", self, "default", "1")
    uci:set("system", self, "trigger", "none")
    led.uci_commit_reload()
end

function led.set_on(self)
    uci:load("system")
    uci:set("system", self, "default", "0")
    uci:set("system", self, "trigger", "none")
    led.uci_commit_reload()
end

function led.set_flashing(self)
    uci:load("system")
    uci:set("system", self, "default", "1")
    uci:set("system", self, "trigger", "timer")
    uci:set("system", self, "delayon", "250")
    uci:set("system", self, "delayoff", "250")
    led.uci_commit_reload()
end

function led.set_quick_flashing(self)
    uci:load("system")
    uci:set("system", self, "default", "1")
    uci:set("system", self, "trigger", "timer")
    uci:set("system", self, "delayon", "100")
    uci:set("system", self, "delayoff", "500")
    led.uci_commit_reload()
end

function led._blue_solid()
    led.set_on("blue")
    utils.log("blue LED going solid")
end

function led._blue_flashing()
    led.set_flashing("blue")
    utils.log("blue LED going flashing")
end

function led._blue_quick_flashing()
    led.set_quick_flashing("blue")
    utils.log("blue LED going quick flashing")
end

function led._blue_off()
    led.set_off("blue")
    utils.log("blue LED going off")
end

return led
