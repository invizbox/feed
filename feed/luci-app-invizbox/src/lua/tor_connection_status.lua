#! /usr/bin/env lua
local utils = require("invizboxutils")

utils.get_tor_info(function(socket)
    local return_string = ""
    local res, data = utils.tor_request(socket, "GETINFO status/circuit-established\r\n")
    if not res then
        return ""
    end
    local status = string.sub(data, string.find(data, "=%w*"))
    if status == "=1" then
        return_string = return_string.."Connected to the Tor network"
    else
        res, data = utils.tor_request(socket, "GETINFO status/bootstrap-phase\r\n")
        if not res then
            return ""
        else
            local percentage = string.gsub(string.sub(data, string.find(data, "PROGRESS=%w*")), "PROGRESS=", "")
            local summary = string.gsub(string.sub(data, string.find(data, "SUMMARY=\"[%w%s]*\"")), "SUMMARY=", "")
            return_string = "Not connected to Tor network ("..percentage.."% - "..summary..")"
        end
    end
    return return_string
end)
