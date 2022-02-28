#! /usr/bin/env lua
local utils = require("invizboxutils")

utils.get_tor_info(function(socket)
    local _, data = utils.tor_request(socket, "GETINFO network-liveness\r\n")
    return data
end)
