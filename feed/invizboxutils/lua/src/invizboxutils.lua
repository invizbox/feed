#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- Useful functions that can be imported by other Lua scripts
-- don't forget to add +invizboxutils to your DEPENDS

local io = require("io")
local http = require("socket.http")
local https = require("ssl.https")
local socket = require("socket")
local ltn12 = require("ltn12")
local os = require("os")
local uci = require("uci").cursor()
local _ubus = require("ubus")

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

function invizboxutils.download(url, file, timeout)
    http.TIMEOUT = timeout or 60
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

function invizboxutils.s_download(url, file, timeout)
    return invizboxutils.success(invizboxutils.download(url, file, timeout))
end

function invizboxutils.post(url, content_type,  body, file)
    http.TIMEOUT = 60
    local ssl = string.sub(url, 1, 5) == "https"
    local code = 0
    local headers = {
        ["content-type"] = content_type,
        ["content-length"] = tostring(#body)
    }
    local resp
    for _ = 1, 3 do
        local body_sink = ltn12.source.string(body)
        if file ~= nil then
            local response_sink = ltn12.sink.file(io.open(file, 'w'))
            if ssl then
                resp, code, _, _ = https.request { method = "POST", url = url, source = body_sink, headers = headers,
                                                  sink = response_sink }
            else
                resp, code, _, _ = http.request { method = "POST", url = url, source = body_sink, headers = headers,
                                                  sink = response_sink }
            end
        else
            if ssl then
                resp, code, _, _ = https.request { method = "POST", url = url, source = body_sink, headers = headers}
            else
                resp, code, _, _ = http.request { method = "POST", url = url, source = body_sink, headers = headers}
            end
        end
        if resp and (invizboxutils.success(code) or invizboxutils.redirect(code)) then
            break
        else
            if code then
                invizboxutils.log("failed to post to url "..url.." with code ["..code.."]")
            else
                invizboxutils.log("failed to post to url "..url.." without error code - most likely captive")
            end
        end
    end
    if resp == nil or (not invizboxutils.success(code) and not invizboxutils.redirect(code)) then
        invizboxutils.log('unable to retrieve:['..url..']')
        return 0
    end
    return code
end

function invizboxutils.s_post(url, content_type, body, file)
    return invizboxutils.success(invizboxutils.post(url, content_type, body, file))
end

function invizboxutils.get_first_line(file)
    local file_handle = io.open(file, "r")
    if file_handle then
        local line = file_handle:read("*line")
        file_handle:close()
        return line
    else
        return ""
    end
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
         size = size + 1
    end
    return size
end

function invizboxutils.table_contains(table, element)
    for _, value in pairs(table) do
        if element == value then
            return true
        end
    end
    return false
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

function invizboxutils.get_known_password(ssid)
    local password = nil
    uci:foreach("known_networks", "network", function(section)
        if section["ssid"] == ssid then
            password = section["key"]
        end
    end)
    return password
end

function invizboxutils.wifi_networks()
    local networks = {}
    local radio =  invizboxutils.getiwinfo("wlan0")
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

function invizboxutils.get_tor_info(callback)
    local return_string
    local sock = socket.tcp()
    sock:settimeout(15)
    if sock and sock:connect("127.0.0.1", 9051) then
        local res, data = invizboxutils.tor_request(sock, "AUTHENTICATE \"\"\r\n")
        if not res then
            return_string = data
        else
            return_string = callback(sock)
        end
    else
        return_string = "Tor Not running"
    end
    sock:close()
    print(return_string)
end

function invizboxutils.tor_request(sock, command)
    -- implementing tor control-spec.txt -especially the 2.3 section about protocol format
    if not sock:send(command) then
        return false, "Cannot send the command to Tor"
    end
    local reply_table = {}
    repeat
        local resp = sock:receive("*l")
        table.insert(reply_table, resp)
    until(not resp or string.sub(resp, 4, 4) == ' ')
    local reply = table.concat(reply_table, "\r\n")
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

function invizboxutils.tor_is_up()
    local command=[[AUTHENTICATE \"\"\r\nGETINFO network-liveness\r\nQUIT\r\n]]
    return os.execute("echo -e \""..command.."\" 2>/dev/null | nc 127.0.0.1 9051 2>/dev/null | grep -q =up") == 0
end

function invizboxutils.get_vpn_interfaces()
    local vpn_list = {}
    uci:foreach("network", "interface", function(section)
        if string.sub(section[".name"], 1, 3) == "vpn" then
            vpn_list[section[".name"]] = section["ifname"]
        end
    end)
    return vpn_list
end

function invizboxutils.apply_vpn_config(some_uci, vpn_interface, tun_name)
    some_uci:load("vpn")
    some_uci:load("admin-interface")
    local selected_server = some_uci:get("vpn", "active", vpn_interface) or some_uci:get("vpn", "active", "name")
    local selected_protocol = some_uci:get("admin-interface", "lan_vpn"..string.sub(vpn_interface, 5, 5), "protocol_id")
                                  or some_uci:get("vpn", "active", "protocol_id")
    if some_uci:get("vpn", selected_server) == "server" and
        (selected_protocol == "filename" or some_uci:get("vpn", selected_protocol) == "protocol") then
        some_uci:load("openvpn")
        some_uci:load("ipsec")
        some_uci:load("wireguard")
        local address = some_uci:get("vpn", selected_server, "address")
        local enabled = "0"
        if some_uci:get("openvpn", vpn_interface, "enabled") == "1"
                or some_uci:get("ipsec", vpn_interface, "enabled") == "1"
                or some_uci:get("wireguard", vpn_interface, "enabled") == "1" then
            enabled = "1"
        end
        if selected_protocol == "filename" or some_uci:get("vpn", selected_protocol, "vpn_protocol") == "OpenVPN" then
            local tmp_file = "/tmp/open"..vpn_interface..".conf"
            local final_file = "/etc/openvpn/open"..vpn_interface..".conf"
            if selected_protocol == "filename" then
                local non_template_file = some_uci:get("vpn", selected_server, "filename")
                os.execute('sed "s/@TUN@/'..tun_name..'/" '..non_template_file..' > '..tmp_file)
            elseif some_uci:get("vpn", selected_protocol, "template") then
                local template = some_uci:get("vpn", selected_protocol, "template")
                os.execute('sed "s/@SERVER_ADDRESS@/'..address..'/; s/@TUN@/'..tun_name..'/" '..template..' > '
                        ..tmp_file)
            else
                return false, 1
            end
            if os.execute("diff "..tmp_file.." "..final_file.." >/dev/null")~=0 then
                os.execute("cp "..tmp_file.." "..final_file.. " >/dev/null")
            end
            some_uci:set("openvpn", vpn_interface, "enabled", enabled)
            some_uci:set("ipsec", vpn_interface, "enabled", "0")
            some_uci:set("wireguard", vpn_interface, "enabled", "0")
        elseif some_uci:get("vpn", selected_protocol, "vpn_protocol") == "IKEv2" then
            some_uci:set("openvpn", vpn_interface, "enabled", "0")
            some_uci:set("ipsec", vpn_interface, "gateway", address)
            some_uci:set("ipsec", vpn_interface, "enabled", enabled)
            some_uci:set("wireguard", vpn_interface, "enabled", "0")
        elseif some_uci:get("vpn", selected_protocol, "vpn_protocol") == "WireGuard" then
            some_uci:set("openvpn", vpn_interface, "enabled", "0")
            some_uci:set("ipsec", vpn_interface, "enabled", "0")
            some_uci:set("wireguard", vpn_interface, "enabled", enabled)
        end
        some_uci:load("dhcp")
        local new_dns_servers = {}
        for _, server in pairs(some_uci:get("dhcp", "vpn"..string.sub(vpn_interface, 5, 5), "server")) do
            if not string.find(server, "@tun") then
                table.insert(new_dns_servers, server)
            end
        end
        local dns_section = selected_protocol
        if selected_protocol == "filename" then
            dns_section = selected_server
        end
        for _, server in pairs(some_uci:get("vpn", dns_section, "dns_server")) do
            table.insert(new_dns_servers, server.."@"..tun_name)
        end
        some_uci:set("dhcp", "vpn"..string.sub(vpn_interface, 5, 5), "server", new_dns_servers)
        some_uci:save("dhcp")
        some_uci:commit("dhcp")
        some_uci:save("ipsec")
        some_uci:commit("ipsec")
        some_uci:save("openvpn")
        some_uci:commit("openvpn")
        some_uci:save("wireguard")
        some_uci:commit("wireguard")
        os.execute("sync")
        return true
    else
        return false, 2
    end
end

function invizboxutils.load_cities(module)
    module.city_1, module.city_2, module.city_3  = nil, nil, nil
    uci:load("vpn")
    local cities = uci:get("vpn", "active", "nearest_cities")
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
    local current_plan = uci:get("vpn", "active", "plan") or ""
    for servers in json_content:gmatch('servers":%s*%["?([^%]]*)') do
        local servers_list = invizboxutils.list_from_string(servers)
        for _, server_name in pairs(servers_list) do
            if uci:get("vpn", invizboxutils.uci_characters(server_name)) then
                local server_plan = uci:get("vpn", invizboxutils.uci_characters(server_name), "plan") or ""
                if server_plan == current_plan then
                    table.insert(usable_servers, invizboxutils.uci_characters(server_name))
                end
            end
        end
        if next(usable_servers) ~= nil then
            math.randomseed(os.time())
            for _, entry in pairs({"vpn_1", "vpn_2", "vpn_3", "vpn_4"}) do
                if uci:get("vpn", "active", entry) then
                    local random_server = usable_servers[math.random(#usable_servers)]
                    uci:set("vpn", "active", entry, random_server)
                end
            end
            return 0
        end
    end
end

function invizboxutils.get_nearest_cities(module)
    uci:load("update")
    local provider_id = uci:get("vpn", "active", "provider") or "unknown"
    if (invizboxutils.s_download("https://update.invizbox.com/nearest/"..provider_id, "/tmp/nearest.json")) then
        local json_content = invizboxutils.read_file("/tmp/nearest.json") or ""
        if string.match(json_content, ".*cities.*city.*city.*city.*") ~= nil
                and string.match(json_content, ".*servers.*servers.*servers.*") ~= nil then
            uci:load("vpn")
            invizboxutils.cities_to_uci(module, json_content)
            invizboxutils.nearest_usable_vpn_server_to_uci(json_content)
            uci:save("vpn")
            uci:commit("vpn")
            -- notify rest-api and update vpn configs
            os.execute("kill -USR1 $(ps | grep [r]est_api | awk '{print $1}') 2>/dev/null")
            for vpn_interface, tun_name in pairs(invizboxutils.get_vpn_interfaces()) do
                invizboxutils.apply_vpn_config(uci, vpn_interface, tun_name)
            end
            os.execute("/etc/init.d/openvpn restart")
            os.execute("/etc/init.d/ipsec restart")
            os.execute("/etc/init.d/wireguard reload")
            invizboxutils.log("Got nearest VPN servers")
        else
            invizboxutils.log("Cannot identify nearest servers")
        end
    end
end

function invizboxutils.csv_to_uci(some_uci, filename, config_name, section_name)
    local ovpn_template_location = "/etc/openvpn/templates/"
    local first_line = true
    local columns = {}
    if not invizboxutils.file_exists(filename) then
        return false, "Invalid filename "..filename
    end
    local successful_replacement = false
    for line in io.lines(filename) do
        if first_line then
            for column_name in line:gmatch('([^,]+)') do
                table.insert(columns, column_name)
            end
            first_line = false
        else
            local i = 1
            local object_name
            local protocol_list = {}
            local dns_server_list = {}
            for column_value in line:gmatch('([^,]+)') do
                if i == 1 then
                    object_name = invizboxutils.uci_characters(column_value)
                    some_uci:set(config_name, object_name, section_name)
                    successful_replacement = true
                end
                if columns[i] == "protocol_ids" then
                    for protocol in column_value:gmatch('([^-]+)') do
                        table.insert(protocol_list, protocol)
                    end
                    some_uci:set(config_name, object_name, "protocol_id", protocol_list)
                elseif columns[i] == "dns_server_1" then
                    table.insert(dns_server_list, column_value)
                elseif columns[i] == "dns_server_2" then
                    table.insert(dns_server_list, column_value)
                    some_uci:set(config_name, object_name, "dns_server", dns_server_list)
                elseif columns[i] == "template" then
                    some_uci:set(config_name, object_name, columns[i], ovpn_template_location..column_value)
                else
                    some_uci:set(config_name, object_name, columns[i], column_value)
                end
                i = i + 1
            end
        end
    end
    return successful_replacement
end

function invizboxutils.get_hardware_model()
    os.execute(". /etc/device_info && echo ${DEVICE_PRODUCT} > /tmp/model.txt")
    return invizboxutils.get_first_line("/tmp/model.txt")
end

return invizboxutils
