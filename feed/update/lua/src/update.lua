#! /usr/bin/env lua
-- Copyright 2021 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt

local utils = require("invizboxutils")
local uci = require("uci").cursor()

local update = {
    country_table = {
        ["Canada East"] = "CA",
        ["Canada West"] = "CA",
        ["UK"] = "GB",
        ["Not Initialised"] = "GB",
        ["US Central"] = "US",
        ["US East"] = "US",
        ["US West"] = "US"
    }
}

function update.load_configuration()
    update.provider_id = uci:get("vpn", "active", "provider") or "unknown"
    os.execute("sed '2!d' /etc/openvpn/login.auth > /tmp/vpn_password.txt")
    update.vpn_password = utils.get_first_line("/tmp/vpn_password.txt")
    update.vpn_username = uci:get("vpn", "active", "username") or ""
    update.server = "http://invizbox46jdxm7ilfet7kikut4nsq7so3x7tdgsp7ktbdqpgax2h3qd.onion/"
    update.use_clearnet = not utils.s_download(update.server.."accessible", "/dev/null")
    if update.use_clearnet then
        utils.log("Onion update server is not accessible, trying the clearnet one.")
        update.server = "https://update.invizbox.com/"
    end
    update.model = utils.get_hardware_model()
    update.f_model = "invizbox_2_firmware"
    if update.model == "InvizBox Go" then
        update.f_model = "invizbox_go_firmware"
    elseif update.model == "InvizBox" then
        update.f_model = "invizbox_original_firmware"
    end
    update.testing = ""
    if uci:get("update", "version", "testing") == "true" then
        update.testing = "_testing"
    end
end

function update.get_current_locations()
    local pre_update_locations = {}
    for vpn_interface, _ in pairs(utils.get_vpn_interfaces()) do
        local current_location = uci:get("vpn", "active", vpn_interface) or uci:get("vpn", "active", "name") or ""
        local location = {}
        local country = uci:get("vpn", current_location, "country")
        if country then
            location["country"] = update.country_table[country] or country
            location["city"] = uci:get("vpn", current_location, "city") or ""
            if location["country"] then
                pre_update_locations[current_location]= location
            end
        end
    end
    return pre_update_locations
end

function update.get_similar_locations(some_uci, location, current_plan)
    local same_country, same_location, all = {}, {}, {}
    some_uci:foreach("vpn", "server", function(section)
        local section_plan = section["plan"] or ""
        if section_plan == current_plan then
            table.insert(all, section[".name"])
            local country = update.country_table[section["country"]] or section["country"]
            if location and country == location["country"] and section["city"] == location["city"] then
                table.insert(same_location, section[".name"])
            elseif location and country == location["country"] then
                table.insert(same_country, section[".name"])
            end
        end
    end)
    return same_location, same_country, all
end

function update.change_locations_if_obsolete(pre_update_locations)
    uci:load("vpn")
    uci:load("admin-interface")
    local replaced = false
    local interfaces = utils.get_vpn_interfaces()
    local current_plan = uci:get("vpn", "active", "plan") or ""
    for vpn_interface, _ in pairs(interfaces) do
        local current_location = uci:get("vpn", "active", vpn_interface)
                or uci:get("vpn", "active", "name")
        local current_location_name = uci:get("vpn", current_location, "name")
        if not current_location_name then
            local network_name = "lan_vpn"..string.sub(vpn_interface, 5, 5)
            local current_protocol_id = uci:get("admin-interface", network_name , "protocol_id")
                    or uci:get("vpn", "active", "protocol_id")
            local location = pre_update_locations[current_location]
            local same_location, same_country, all = update.get_similar_locations(uci, location, current_plan)
            local new_location
            if current_location == "NotInitialised" then
                if #same_country ~= 0 then
                    new_location = same_country[math.random(#same_country)]
                else
                    new_location = all[math.random(#all)]
                end
            elseif location then
                if #same_location ~= 0 then
                    new_location = same_location[math.random(#same_location)]
                elseif #same_country ~= 0 then
                    new_location = same_country[math.random(#same_country)]
                end
            end
            if new_location then
                uci:set("vpn", "active", vpn_interface, new_location)
                local new_location_protocol_ids = uci:get("vpn", new_location, "protocol_id")
                if type(new_location_protocol_ids) == "table"
                        and not utils.table_contains(new_location_protocol_ids, current_protocol_id) then
                    if not uci:set("admin-interface", network_name , "protocol_id", new_location_protocol_ids[1]) then
                        uci:set("vpn", "active", "protocol_id", new_location_protocol_ids[1])
                    end
                elseif type(new_location_protocol_ids) ~= "table"
                        and new_location_protocol_ids ~= current_protocol_id then
                    if not uci:set("admin-interface", network_name , "protocol_id", new_location_protocol_ids) then
                        uci:set("vpn", "active", "protocol_id", new_location_protocol_ids)
                    end
                end
                replaced = true
            end
        end
    end
    if replaced then
        -- notify rest-api and update openvpn configs
        uci:save("vpn")
        uci:commit("vpn")
        uci:save("admin-interface")
        uci:commit("admin-interface")
        os.execute("kill -USR1 $(ps | grep [r]est_api | awk '{print $1}') 2>/dev/null")
        for vpn_interface, tun_name in pairs(interfaces) do
            utils.apply_vpn_config(uci, vpn_interface, tun_name)
        end
        os.execute("/etc/init.d/ipsec stop")
        os.execute("/etc/init.d/openvpn stop")
        os.execute("/etc/init.d/openvpn start")
        os.execute("/etc/init.d/ipsec start")
        utils.log("Updated locations which were missing after update to their closest match")
    end
end

function update.deal_with_new_vpn_config(content_sha)
    local ovpn_template_location = "/etc/openvpn/templates/"
    os.execute("mkdir -p "..ovpn_template_location)
    if os.execute("unzip -q -o -d /tmp/potential_configs /tmp/vpn.zip") == 0 then
        utils.log("New VPN configurations have been downloaded")

        -- move templates and certificates
        os.execute("mv /tmp/potential_configs/*.template "..ovpn_template_location.." &> /var/log/opkg_update.log")
        os.execute("mv /tmp/potential_configs/*.crt /etc/openvpn &> /var/log/opkg_update.log")

        -- get information from current locations if available
        local pre_update_locations = update.get_current_locations()

        -- delete previous server entries with protocol_id and all protocol entries
        uci:load("vpn")
        uci:foreach("vpn", "server", function(s)
            if uci:get("vpn", s['.name'], "protocol_id") then
                uci:delete("vpn", s['.name'])
            end
        end)
        uci:foreach("vpn", "protocol", function(s)
            uci:delete("vpn", s['.name'])
        end)

        -- add new ones from CSV
        local ok_s, changed_s = pcall(utils.csv_to_uci, uci, "/tmp/potential_configs/servers.csv", "vpn",
                "server")
        local ok_p, changed_p = pcall(utils.csv_to_uci, uci, "/tmp/potential_configs/protocols.csv", "vpn",
                "protocol")
        if ok_s and changed_s and ok_p and changed_p then
            uci:save("vpn")
            uci:commit("vpn")
            update.change_locations_if_obsolete(pre_update_locations)
            utils.log("New VPN configurations are now in place")
        else
            utils.log("Previous VPN configurations were kept")
        end
        uci:load("update")
        uci:set("update", "active", "active")
        uci:set("update", "active", "current_vpn_sha", content_sha) -- even if invalid, we've dealt with them
        uci:save("update")
        uci:commit("update")
        return true
    end
    return false
end

function update.update_vpn()
    utils.log("Checking if new VPN configuration is available.")
    local vpn_url = update.server.."vpn"..update.testing.."/latest/"..update.provider_id.."_vpn_configuration"
    if update.provider_id == "myexpatnetwork" then
        if update.vpn_username ~= "" and update.vpn_password ~= "" then
            if utils.s_post(update.server.."myexpatnetwork_ib2_vpn_configuration", "application/json",
                    '{"username": "'..update.vpn_username:gsub('"', '\\"')..'", "password": "'
                            ..update.vpn_password:gsub('"', '\\"')..'"}', "/tmp/vpn.zip") then
                update.deal_with_new_vpn_config("abcdef") -- changing to tell netwatch2 we've updated
            end
        end
    elseif utils.s_download(vpn_url ..".content.sha", "/tmp/latest_vpn.content.sha") then
        local content_sha = string.gmatch(utils.get_first_line("/tmp/latest_vpn.content.sha"), "%S+")()
        if content_sha ~= uci:get("update", "active", "current_vpn_sha") then
            utils.log("Downloading new VPN configuration...")
            if utils.s_download(vpn_url ..".zip", "/tmp/vpn.zip") and
                    utils.s_download(vpn_url ..".sha", "/tmp/vpn_config_download.sha") then
                os.execute("sha256sum /tmp/vpn.zip > /tmp/vpn_config_received.sha")
                local initial_sha = string.gmatch(utils.get_first_line("/tmp/vpn_config_download.sha"), "%S+")()
                local download_sha = string.gmatch(utils.get_first_line("/tmp/vpn_config_received.sha"), "%S+")()
                if initial_sha == download_sha then
                    update.deal_with_new_vpn_config(content_sha)
                else
                    utils.log("Invalid sha256 after download, will try again later")
                    return 1
                end
            else
                utils.log("Unable to obtain a more up to date VPN configuration, will try again later")
                return 2
            end
            os.execute("rm -rf /tmp/potential_configs")
        else
            utils.log("We already have the most up to date VPN configuration")
            return 3
        end
    else
        utils.log("Unable to get a content SHA for the latest VPN configuration, will try again later")
        return 4
    end
    utils.log("Successfully updated template, certificate and VPN uci settings")
    return true
end

function update.new_version_higher(old_version, new_version)
    local old_major, old_minor, old_patch = old_version:match"([^.]*).([^.]*).(.*)"
    local new_major, new_minor, new_patch = new_version:match"([^.]*).([^.]*).(.*)"
    if tonumber(old_major) == nil or tonumber(new_major) == nil or tonumber(old_minor) == nil
            or tonumber(new_minor) == nil or tonumber(old_patch) == nil or tonumber(new_patch) == nil then
        return false
    end
    if tonumber(old_major) < tonumber(new_major) then
        return true
    elseif tonumber(old_major) > tonumber(new_major) then
        return false
    else
        if tonumber(old_minor) < tonumber(new_minor) then
            return true
        elseif tonumber(old_minor) > tonumber(new_minor) then
            return false
        else
            if tonumber(old_patch) < tonumber(new_patch) then
                return true
            else
                return false
            end
        end
    end
end

function update.update_firmware()
    utils.log("Checking if new firmware is available.")
    local f_url = update.server..update.f_model..update.testing.."/latest/"..update.model:gsub(" ", "-").."-"
            ..update.provider_id.."-"
    if utils.s_download(f_url.."version.txt", "/tmp/latest_firmware_version.txt") then
        uci:load("update")
        local current_version = uci:get("update", "version", "firmware") or "unknown"
        local new_version = utils.get_first_line("/tmp/latest_firmware_version.txt")
        if update.new_version_higher(current_version, new_version) then
            if utils.file_exists("/etc/update/firmware/new_firmware-"..new_version.."-sysupgrade.bin") then
                utils.log("We have already downloaded that update, finished for now.")
                uci:set("update", "version", "new_firmware", new_version)
                uci:save("update")
                uci:commit("update")
                return 1
            else
                utils.log("Downloading new firmware.")
                local firmware_string = string.format(f_url.."%s-sysupgrade.bin", new_version)
                local sha_string = string.format(f_url.."%s-sysupgrade.sha", new_version)
                utils.log(firmware_string)
                if utils.s_download(firmware_string, "/tmp/firmware_download.bin") and
                        utils.s_download(sha_string, "/tmp/firmware_download.sha") then
                    os.execute("sha256sum /tmp/firmware_download.bin > /tmp/firmware_received.sha")
                    local initial_sha = string.gmatch(utils.get_first_line("/tmp/firmware_download.sha"), "%S+")()
                    local download_sha = string.gmatch(utils.get_first_line("/tmp/firmware_received.sha"), "%S+")()
                    if initial_sha == download_sha then
                        os.execute("rm -rf /etc/update/firmware; mkdir -p /etc/update/firmware && "
                                .."mv /tmp/firmware_download.bin /etc/update/firmware/new_firmware-"
                                ..new_version.."-sysupgrade.bin")
                        utils.log("New firmware now available at /etc/update/firmware/new_firmware-"
                                ..new_version.."-sysupgrade.bin")
                        uci:set("update", "version", "new_firmware", new_version)
                        uci:save("update")
                        uci:commit("update")
                    else
                        utils.log("Downloaded binary doesn't match downloaded hash, will try again later")
                        return 2
                    end
                else
                    utils.log("Unable to download the latest firmware, will try again later.")
                    return 3
                end
            end
        else
            utils.log("The current version is the latest")
            return 4
        end
    else
        utils.log("Unable to check if a new version is available, will try again later.")
        return 5
    end
    return true
end

function update.restore_material_theme()
    os.execute("uci set luci.themes.Material=/luci-static/material 2>/dev/null; "
            .."uci set luci.main.mediaurlbase=/luci-static/material 2>/dev/null; "
            .."uci commit luci 2>/dev/null")
end

function update.update_opkg()
    local upgrade_command = "PACKS=\"$(opkg list-upgradable | awk '{ printf \"%s \",$1 }')\"; "..
            "if [[ ! -z \"${PACKS}\" ]]; then "..
                "opkg install ${PACKS} &> /var/log/opkg_upgrade.log; "..
            "else "..
                "echo $'\\nNo packages to install\\n' &> /var/log/opkg_upgrade.log; "..
            "fi"
    if (update.use_clearnet == false) then
        utils.log("Updating opkg via .onion.")
        os.execute("opkg update > /var/log/opkg_update.log 2>&1")
        utils.log(utils.run_and_log("cat /var/log/opkg_update.log"))
        os.execute(upgrade_command)
        utils.log(utils.run_and_log("cat /var/log/opkg_upgrade.log"))
        update.restore_material_theme()
        return 0
    else
        utils.log("Updating opkg via clearnet.")
        os.execute("OPKG_CONF_DIR=/etc/opkg_clear opkg update &> /var/log/opkg_update.log")
        utils.log(utils.run_and_log("cat /var/log/opkg_update.log"))
        os.execute(upgrade_command)
        utils.log(utils.run_and_log("cat /var/log/opkg_upgrade.log"))
        update.restore_material_theme()
        return 1
    end
end

function update.update_vpn_status()
    utils.log("Checking VPN subscription status")
    local vpn_status_url = update.server..update.provider_id.."_vpn_status/"..update.vpn_username
    utils.log(vpn_status_url)
    if (update.vpn_username ~= "" and utils.s_download(vpn_status_url, "/tmp/vpn_status.json")) then
        utils.log("Got updated VPN subscription status")
        local json_content = utils.read_file("/tmp/vpn_status.json") or ""
        if string.match(json_content, ".*provider.*") ~= nil then
            local vpn_provider = utils.hack_json(json_content, "provider")
            if (vpn_provider == "wlvpn") then
                if update.vpn_password ~= "" then
                    utils.s_post(update.server.."migrate_user", "application/json",
                                 '{"username": "'..update.vpn_username:gsub('"', '\\"')..'", "password": "'
                                 ..update.vpn_password:gsub('"', '\\"')..'"}')
                else
                    utils.log("Unable to read password from login.auth")
                end
            end
        end
        if string.match(json_content, ".*registered.*expiry.*renewal.*") ~= nil then
            uci:load("vpn")
            local registered = utils.hack_json(json_content, "registered")
            if (registered == "true") then
                uci:set("vpn", "active", "registered", "true")
            elseif (registered == "false") then
                uci:set("vpn", "active", "registered", "false")
            end
            local renewal = utils.hack_json(json_content, "renewal")
            if (renewal == "true") then
                uci:set("vpn", "active", "renewal", "true")
            elseif (renewal == "false") then
                uci:set("vpn", "active", "renewal", "false")
            end
            local expiry = utils.hack_json(json_content, "expiry")
            if (expiry ~= nil and expiry == "Never" or string.len(expiry) == 10 or string.len(expiry) == 11) then
                uci:set("vpn", "active", "expiry", expiry)
            end
            uci:save("vpn")
            uci:commit("vpn")
            return true
        else
            utils.log("received invalid JSON from server")
            return 1
        end
    else
        utils.log("Did not retrieve VPN subscription status this time, will try again later.")
        return 2
    end
end

function update.version_only()
    local f_url = update.server..update.f_model..update.testing.."/latest/"..update.model:gsub(" ", "-").."-"
            ..update.provider_id.."-"
    if utils.s_download(f_url.."version.txt", "/tmp/latest_invizbox_version.txt") then
        uci:load("update")
        local current_version = uci:get("update", "version", "firmware")
        utils.log("current version: "..current_version)
        local new_version = utils.get_first_line("/tmp/latest_invizbox_version.txt")
        utils.log("new version: "..new_version)
        if update.new_version_higher(current_version, new_version) then
            utils.log("new version is higher - setting it in config")
            uci:set("update", "version", "new_firmware", new_version)
            uci:save("update")
            uci:commit("update")
        end
    end
end

function update.update_blacklists()
    utils.log("Checking if new blacklists configuration is available.")
    local blacklists_url = update.server.."dns_blacklist"..update.testing.."/latest/blacklists"
    if utils.s_download(blacklists_url..".content.sha", "/tmp/latest_blacklists.content.sha") then
        local content_sha = string.gmatch(utils.get_first_line("/tmp/latest_blacklists.content.sha"), "%S+")()
        if content_sha ~= uci:get("update", "active", "current_blacklists_sha") then
            utils.log("Downloading new Blacklists...")
            if utils.s_download(blacklists_url..".zip", "/tmp/blacklists.zip") and
                    utils.s_download(blacklists_url..".sha", "/tmp/blacklists_download.sha") then
                os.execute("sha256sum /tmp/blacklists.zip > /tmp/blacklists_received.sha")
                local initial_sha = string.gmatch(utils.get_first_line("/tmp/blacklists_download.sha"), "%S+")()
                local download_sha = string.gmatch(utils.get_first_line("/tmp/blacklists_received.sha"), "%S+")()
                if initial_sha == download_sha and
                        os.execute("unzip -q -o -d /tmp/new_blacklists /tmp/blacklists.zip") == 0 then
                    utils.log("New backlists available in /tmp/new_blacklists")

                    -- delete previous blacklists
                    uci:load("blacklists")
                    local section = "blacklist"
                    uci:foreach("blacklists", section, function(s)
                        uci:delete("blacklists", s['.name'])
                    end)

                    -- add new ones from CSV
                    local successful_replacement = false
                    for line in io.lines("/tmp/new_blacklists/blacklists.csv") do
                        local matching_regex = "([^,]+),([^,]+),([^,]+),([^,]+)"
                        local name, source, file, description = line:match(matching_regex)
                        if name ~= "name" then
                            local uci_name = utils.uci_characters(file:match(".*/(.*)"))
                            uci:set("blacklists", uci_name, "blacklist")
                            uci:set("blacklists", uci_name, "name", name)
                            uci:set("blacklists", uci_name, "source", source)
                            uci:set("blacklists", uci_name, "file", file)
                            uci:set("blacklists", uci_name, "description", description)
                            successful_replacement = true
                        end
                    end
                    if successful_replacement then
                        uci:save("blacklists")
                        uci:commit("blacklists")
                    end

                    -- move blacklists
                    os.execute("mv /tmp/new_blacklists/* /etc/dns_blacklist/ &> /var/log/opkg_update.log")

                    uci:load("update")
                    uci:set("update", "active", "active")
                    uci:set("update", "active", "current_blacklists_sha", content_sha)
                    uci:save("update")
                    uci:commit("update")
                else
                    utils.log("Invalid sha256 after download, will try again later")
                    return 1
                end
            else
                utils.log("Unable to obtain a more up to date blacklists, will try again later")
                return 2
            end
            os.execute("rm -rf /tmp/new_blacklists")
        else
            utils.log("We already have the most up to date blacklists")
            return 3
        end
    else
        utils.log("Unable to get a content SHA for the latest blacklists, will try again later")
        return 4
    end
    utils.log("Successfully updated blacklists")
    return true
end

function update.do_update()
    -- hacking log function here to be able to use invizboxutils with logging and yet avoid an empty log file when
    -- unable to acquire the lock above
    local log_file = io.open("/var/log/update.log", "w")
    local old_log = utils.log
    utils.log = function(string)
        log_file:write(string.."\n")
        log_file:flush()
    end
    utils.log("Update started.")

    uci:load("update")
    uci:load("vpn")
    update.load_configuration()

    local success, return_value
    local notify_rest_api = false
    if update.model ~= "InvizBox" then
        utils.log("Updating opkg packages.")
        success, return_value = pcall(update.update_opkg)
        if not success then
            utils.log("Error updating opkg packages: "..return_value)
        end
    end
    if update.provider_id == "invizbox" then
        utils.log("Updating VPN status.")
        success, return_value = pcall(update.update_vpn_status)
        if not success then
            utils.log("Error updating VPN status: "..return_value)
        end
    end
    utils.log("Updating VPN locations.")
    success, return_value = pcall(update.update_vpn)
    if success then
        notify_rest_api = (return_value == true) or notify_rest_api
    else
        utils.log("Error updating VPN locations: "..return_value)
    end
    if update.model == "InvizBox" then
        utils.log("Updating version.")
        success, return_value = pcall(update.version_only)
        if not success then
            utils.log("Error updating version: "..return_value)
        end
    else
        utils.log("Updating firmware.")
        success, return_value = pcall(update.update_firmware)
        if success then
            notify_rest_api = (return_value == true) or notify_rest_api
        else
            utils.log("Error updating firmware: "..return_value)
        end
    end
    if update.model == "InvizBox 2" then
        utils.log("Updating blacklists.")
        success, return_value = pcall(update.update_blacklists)
        if success then
            notify_rest_api = (return_value == true) or notify_rest_api
        else
            utils.log("Error updating blacklists: "..return_value)
        end
    end
    if notify_rest_api then
        os.execute("kill -USR1 $(ps | grep [r]est_api | awk '{print $1}') 2>/dev/null")
    end
    utils.log("Update complete.")
    utils.log = old_log
    log_file:close()
end

function update.update()
    -- prevent multiple executions of script in parallel (if lock is left as update is killed - only a restart or manual
    -- removal of lock file will allow for a successful run of update
    if os.execute("lock -n /var/lock/update.lock") ~= 0 then
        utils.log("Unable to obtain update lock.")
        return false
    end

    pcall(update.do_update)

    os.execute("lock -u /var/lock/update.lock")
    return true
end

if not pcall(getfenv, 4) then
    update.update()
end

return update
