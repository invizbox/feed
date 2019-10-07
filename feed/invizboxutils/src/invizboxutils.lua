#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Useful functions that can be imported by other Lua scripts
-- don't forget to add +invizboxutils to your DEPENDS

local io = require "io"
local http = require "socket.http"
local https = require "ssl.https"
local socket = require "socket"
local ltn12 = require "ltn12"
local uci = require("uci").cursor()
local _ubus = require "ubus"

local invizboxutils ={}
invizboxutils.ubus_connection = nil

function invizboxutils.success(http_code)
    if http_code then
        return http_code >= 200 and http_code < 300
    else
        return false
    end
end

function invizboxutils.redirect(http_code)
    if http_code then
        return http_code >= 300 and http_code < 400
    else
        return false
    end
end

function invizboxutils.download(url, file)
    local ssl = string.sub(url, 1, 5) == "https"
    local code = 0
    local resp
    for _ = 1, 3 do
        local sink = ltn12.sink.file(io.open(file, 'w'))
        if ssl then
            resp, code, _, _ = https.request { url = url, sink = sink }
        else
            resp, code, _, _ = http.request { url = url, sink = sink }
        end
        if resp and (invizboxutils.success(code) or invizboxutils.redirect(code)) then
            break
        else
            if code then
                invizboxutils.log("failed to download url "..url.." with code ["..code.."]")
            else
                invizboxutils.log("failed to download url "..url.." without error code - most likely captive")
            end
        end
    end
    if resp == nil or (not invizboxutils.success(code) and not invizboxutils.redirect(code)) then
        invizboxutils.log('unable to retrieve:['..url..']')
        return 0
    end
    return code
end

function invizboxutils.s_download(url, file)
    return invizboxutils.success(invizboxutils.download(url, file))
end

function invizboxutils.post(url, content_type,  body)
    local ssl = string.sub(url, 1, 5) == "https"
    local code = 0
    local headers = {
        ["content-type"] = content_type,
        ["content-length"] = tostring(#body)
    }
    local resp
    for _ = 1, 3 do
        local sink = ltn12.source.string(body)
        if ssl then
            resp, code, _, _ = http.request { method = "POST", url = url, source = sink, headers = headers }
        else
            resp, code, _, _ = http.request { method = "POST", url = url, source = sink, headers = headers }
        end
        if resp and (invizboxutils.success(code) or invizboxutils.redirect(code)) then
            break
        else
            if code then
                invizboxutils.log("failed to download url "..url.." with code ["..code.."]")
            else
                invizboxutils.log("failed to download url "..url.." without error code - most likely captive")
            end
        end
    end
    if resp == nil or (not invizboxutils.success(code) and not invizboxutils.redirect(code)) then
        invizboxutils.log('unable to retrieve:['..url..']')
        return 0
    end
    return code
end

function invizboxutils.s_post(url, content_type, body)
    return invizboxutils.success(invizboxutils.post(url, content_type, body))
end

function invizboxutils.get_first_line(file)
    local file_handle = assert(io.open(file, "r"))
    local line = file_handle:read("*line")
    file_handle:close()
    return line
end

function invizboxutils.read_file(path, mode)
    if mode == nil then
        mode = "r"
    end
    local file = io.open(path, mode)
    if not file then
        return nil
    end
    local content = file:read "*a"
    file:close()
    return content
end

function invizboxutils.hack_json(string, key)
    return string.match(string, key..'":%s*"?([^",}]*)')
end

function invizboxutils.file_exists(file)
    local file_handle = io.open(file, "r")
    if file_handle then
        file_handle:close()
        return true
    end
    return false
end

function invizboxutils.sleep(sec)
    for _=1, sec*10 do
        socket.select(nil, nil, .1) -- to stop within one second
    end
end

function invizboxutils.run_and_log(command)
	local handle = io.popen(command)
	local output = handle:read("*a")
	handle:close()
	return output
end

function invizboxutils.log(string)
    io.stdout:write(string.."\n")
    io.stdout:flush()
end

function invizboxutils.table_print(data)
    if type(data) == "table" then
        for key, value in pairs(data) do
            print(key)
            invizboxutils.table_print(value)
        end
    else
        print(data)
    end
end

function invizboxutils.table_size(table)
    local size = 0
    for _, _ in pairs(table) do
         size = size +1
    end
    return size
end

function invizboxutils.uci_characters(identifier)
    local uci_value = string.gsub(identifier, '[^a-zA-Z0-9_]', '')
    if uci_value == "" then
        local md5_output = invizboxutils.run_and_log("echo '"..identifier.."' | md5sum")
        uci_value = string.gmatch(md5_output, "%S+")()
    end
    return uci_value
end

function invizboxutils.getiwinfo(ifname)
	local stat, iwinfo = pcall(require, "iwinfo")

    if not invizboxutils._ubus_connection then
        invizboxutils._ubus_connection = _ubus.connect()
    end
    local wstate = invizboxutils._ubus_connection:call("network.wireless", "status", {}) or {}

    if type(wstate[ifname]) == "table" and
       type(wstate[ifname].interfaces) == "table" and
       type(wstate[ifname].interfaces[1]) == "table" and
       type(wstate[ifname].interfaces[1].ifname) == "string"
    then
        ifname = wstate[ifname].interfaces[1].ifname
    end

    local type = stat and iwinfo.type(ifname)
    local x = type and iwinfo[type] or { }
    return setmetatable({}, {
        __index = function(_, k)
            if k == "ifname" then
                return ifname
            elseif x[k] then
                return x[k](ifname)
            end
        end
    })
end

function invizboxutils.wifi_networks()
    local radio = invizboxutils.getiwinfo("ap0")
    local networks = {}
    for _, network in ipairs(radio.scanlist or {} ) do
        if network.ssid ~= nil and network.quality ~= nil and network.quality_max ~= nil
                 and network.quality_max ~= 0 and network.encryption ~= nil then
            local quality = math.floor(network.quality * 100 / network.quality_max)
            local encryption = "none"
            if network.encryption.wep then
                encryption = "wep"
            elseif network.encryption.wpa > 0 then
                encryption = "psk-mixed"
            end
            if networks[network.ssid] == nil or quality > networks[network.ssid].quality then
                networks[network.ssid] = {quality = quality, encryption = encryption}
            end
        end
    end
    local ordered_index = {}
    for key in pairs(networks) do
        table.insert(ordered_index, key)
    end
    table.sort(ordered_index, function(a, b) return networks[a].quality > networks[b].quality end)
    return ordered_index, networks
end

function invizboxutils.tor_request(sock, command)
    if not sock:send(command) then
        return false, "Cannot send the command to Tor"
    end
    local reply_table = {}
    local resp = sock:recv(1000)
    while resp do
        table.insert(reply_table, resp)
        if string.len(resp) < 1000 then break end
        resp = sock:recv(1000)
    end
    local reply = table.concat(reply_table)

    if not resp then
        return false, "Cannot read the response from Tor"
    end
    local i, j = string.find(reply, "^%d%d%d")
    if j ~= 3 then
        return false, "Malformed response from Tor"
    end
    local code = string.sub(reply, i, j)
    if code ~= "250" and (code ~= "650" or command ~= "") then
        return false, "Tor responded with an error: "..reply
    end

    return true, reply
end

function invizboxutils.get_vpn_interfaces()
    local vpn_list = {}
    local config_name = "network"
    uci:foreach(config_name, "interface", function(section)
        if string.sub(section[".name"], 1, 3) == "vpn" then
            vpn_list[section[".name"]] = section["ifname"]
        end
    end)
    return vpn_list
end

function invizboxutils.apply_vpn_config(some_uci, vpn_interface, tun_name)
    local config_name = "vpn"
    some_uci:load(config_name)
    local selected_server = some_uci:get(config_name, "active", vpn_interface)
            or some_uci:get(config_name, "active", "name")
    local tmp_file = "/tmp/open"..vpn_interface..".conf"
    local final_filename = "/etc/openvpn/open"..vpn_interface..".conf"
    if some_uci:get(config_name, selected_server) == "server" then
        if some_uci:get(config_name, selected_server, "template") then
            local template = some_uci:get(config_name, selected_server, "template")
            local address = some_uci:get(config_name, selected_server, "address")
            os.execute('sed "s/@SERVER_ADDRESS@/'..address..'/; s/@TUN@/'..tun_name..'/" '..template..' > '..tmp_file)
        elseif some_uci:get(config_name, selected_server, "filename") then
            local non_template_filename = some_uci:get(config_name, selected_server, "filename")
            os.execute('sed "s/@TUN@/'..tun_name..'/" '..non_template_filename..' > '..tmp_file)
        end
        if os.execute("diff "..tmp_file.." "..final_filename.." >/dev/null")~=0 and
                os.execute("cp "..tmp_file.." "..final_filename.. " >/dev/null") == 0 then
            return true
        else
            return false, 2
        end
    else
        return false, 3
    end
end

function invizboxutils.load_cities(module)
    module.city_1, module.city_2, module.city_3  = nil, nil, nil
    local config_name = "vpn"
    uci:load(config_name)
    local cities = uci:get(config_name, "active", "nearest_cities")
    if cities then
        module.city_1, module.city_2, module.city_3  = cities:match("([^,]+), ([^,]+), ([^,]+)")
    end
end

function invizboxutils.cities_to_uci(module, json_content)
    local city_iterator = json_content:gmatch('city":%s*"?([^"]*)"')
    module.city_1 = city_iterator()
    module.city_2 = city_iterator()
    module.city_3 = city_iterator()
    uci:set("vpn", "active", "nearest_cities", module.city_1..", "..module.city_2..", "..module.city_3)
end

function invizboxutils.list_from_string(servers)
    local servers_string = '"'..servers..','
    local servers_list = {}
    for server_name in servers_string:gmatch('"?([^"]*)",') do
       table.insert(servers_list, server_name)
    end
    return servers_list
end

function invizboxutils.nearest_usable_vpn_server_to_uci(json_content)
    local usable_servers = {}
    local config_name = "vpn"
    for servers in json_content:gmatch('servers":%s*%["?([^%]]*)') do
        local servers_list = invizboxutils.list_from_string(servers)
        for _, server_name in pairs(servers_list) do
            if uci:get(config_name, invizboxutils.uci_characters(server_name)) then
                table.insert(usable_servers, invizboxutils.uci_characters(server_name))
            end
        end
        if next(usable_servers) ~= nil then
            math.randomseed(os.time())
            for _, entry in pairs({"vpn", "vpn_1", "vpn_2", "vpn_3", "vpn_4"}) do
                if uci:get(config_name, "active", entry) then
                    uci:set(config_name, "active", entry, usable_servers[math.random(#usable_servers)])
                end
            end
            return 0
        end
    end
end

function invizboxutils.get_nearest_cities(module)
    local config_name = "update"
    uci:load(config_name)
    local nearest_servers_url = uci:get(config_name, "server", "clear")..uci:get(config_name, "urls", "nearest_cities")
    if (invizboxutils.s_download(nearest_servers_url, "/tmp/nearest.json")) then
        local json_content = invizboxutils.read_file("/tmp/nearest.json") or ""
        if string.match(json_content, ".*cities.*city.*city.*city.*") ~= nil
                and string.match(json_content, ".*servers.*servers.*servers.*") ~= nil then
            config_name = "vpn"
            uci:load(config_name)
            invizboxutils.cities_to_uci(module, json_content)
            invizboxutils.nearest_usable_vpn_server_to_uci(json_content)
            uci:save(config_name)
            uci:commit(config_name)
            -- notify rest-api and update openvpn configs
            os.execute("kill -USR1 $(ps | grep [r]est_api | awk '{print $1}') 2>/dev/null")
            for vpn_interface, tun_name in pairs(invizboxutils.get_vpn_interfaces()) do
                invizboxutils.apply_vpn_config(uci, vpn_interface, tun_name)
            end
            os.execute("/etc/init.d/openvpn restart")
            invizboxutils.log("Got nearest VPN servers")
        else
            invizboxutils.log("Cannot identify nearest servers")
        end
    end
end

return invizboxutils
