#! /usr/bin/env lua
local utils = require("invizboxutils")

utils.get_tor_info(function(socket)
    local return_string = ""
    local res, data = utils.tor_request(socket, "GETINFO version\r\n")
    if not res then
        return_string = return_string..data
        return return_string
    else
        return_string = return_string..string.match(data, "%d.%d.%d.%d+").." : "
    end
    res, data = utils.tor_request(socket, "GETINFO status/version/current\r\n")
    if not res then
        return_string = return_string..data
        return return_string
    else
        return_string = return_string..string.match(data, "%w+", string.find(data, "="))
    end
    return return_string
end)
