#! /usr/bin/env lua
local utils = require("invizboxutils")

local function lines(str)
  local t = {}
  local function helper(line)
      table.insert(t, line)
      return ""
  end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

utils.get_tor_info(function(socket)
    local return_string
    local res, data = utils.tor_request(socket, "GETINFO circuit-status\r\n")
    if not res then
        return
    else
        local clean_data = string.gsub(string.gsub(data, "\r\n250 .+$", ""), "^250+[^\n]*", "")
        local data_lines = lines(clean_data)
        local return_table = {}
        for _, circstat in pairs(data_lines) do
            if circstat ~= "" then
               local tmp = string.gsub(circstat, "BUILD.*", "")
               table.insert(return_table, tmp)
            end
        end
        return_string = table.concat(return_table, "<br>")
    end
    utils.tor_request(socket, "QUIT\r\n")
    return return_string
end)
