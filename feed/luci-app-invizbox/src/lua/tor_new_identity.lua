#! /usr/bin/env lua
local utils = require("invizboxutils")

utils.get_tor_info(function(socket)
    local return_string = ""
    local res, data = utils.tor_request(socket, "SIGNAL NEWNYM\r\n")
    if not res then
        return_string = return_string..data
    end
    return return_string
end)
