#! /usr/bin/env lua
local sys = require("luci.sys")
local uci = require("uci").cursor()
local utils = require("invizboxutils")

if utils.apply_vpn_config(uci, "vpn_1", "tun1") then
    sys.call("/etc/init.d/openvpn stop")
    sys.call("/etc/init.d/ipsec stop")
    sys.call("/etc/init.d/openvpn start")
    sys.call("/etc/init.d/ipsec start")
end
