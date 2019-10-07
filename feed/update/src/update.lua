#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- updates VPN configuration and firmware

local utils = require "invizboxutils"
local uci = require("uci").cursor()

local update = {}
update.config = {}
update.locations = {}
update.country_table = {}
update.country_table["Canada East"] = "CA"
update.country_table["Canada West"] = "CA"
update.country_table["LU"] = "DE"
update.country_table["UK"] = "GB"
update.country_table["US Central"] = "US"
update.country_table["US East"] = "US"
update.country_table["US West"] = "US"

function update.load_update_config()
    utils.log("Loading configuration")
    local config_name = "update"
    uci:load(config_name)
    local new_firmware_path = uci:get(config_name, "urls", "new_firmware_path")
    local test_url = uci:get(config_name, "server", "onion")..new_firmware_path.."version.txt"
    utils.log("Checking if .onion is accessible.")
    if utils.s_download(test_url, "/tmp/latest_vpn_configuration.content.sha") then
        utils.log(".onion is accessible.")
        update.config.server = uci:get(config_name, "server", "onion")
        update.config.use_clearnet = false
    else
        utils.log(".onion is inaccessible, switch to clearnet.")
        update.config.server = uci:get(config_name, "server", "clear")
        update.config.use_clearnet = true
    end

    update.config.new_firmware_version = update.config.server.. new_firmware_path.."version.txt"
    if uci:get(config_name, "active", "firmware") == "true" then
        update.config.new_firmware_bin = update.config.server..new_firmware_path.."%s-sysupgrade.bin"
        update.config.new_firmware_sha = update.config.server..new_firmware_path.."%s-sysupgrade.sha"
    end
    if uci:get(config_name, "active", "vpn") == "true" then
        local vpn_config = uci:get(config_name, "urls", "vpn_configuration")
        update.config.vpn_configuration_zip = update.config.server..vpn_config..".zip"
        update.config.vpn_configuration_sha = update.config.server..vpn_config..".sha"
        update.config.vpn_configuration_content_sha = update.config.server..vpn_config..".content.sha"
        update.config.current_vpn_sha = uci:get(config_name, "active", "current_vpn_sha")
        update.config.vpn_status = update.config.server..uci:get(config_name, "urls", "vpn_status")
    end
    if uci:get(config_name, "active", "blacklists") == "true" then
        local blacklists_path = uci:get(config_name, "urls", "blacklists")
        update.config.blacklists_zip = update.config.server..blacklists_path..".zip"
        update.config.blacklists_sha = update.config.server..blacklists_path..".sha"
        update.config.blacklists_content_sha = update.config.server..blacklists_path..".content.sha"
        update.config.current_blacklists_sha = uci:get(config_name, "active", "current_blacklists_sha")
    end
    utils.log("Configuration loaded")
end

function update.get_current_locations()
    local config_name = "vpn"
    local section_name = "active"
    local pre_update_locations = {}
    for vpn_interface, _ in pairs(utils.get_vpn_interfaces()) do
        local current_location = uci:get(config_name, section_name, vpn_interface)
                or uci:get(config_name, section_name, "name")
        local location = {}
        local country = uci:get(config_name, current_location, "country")
        location["country"] = update.country_table[country] or country
        location["city"] = uci:get(config_name, current_location, "city")
        if location["country"] then
            pre_update_locations[current_location]= location
        end
    end
    return pre_update_locations
end

function update.get_similar_locations(location)
    local same_country, same_location = {}, {}
    uci:foreach("vpn", "server", function(section)
        local country = update.country_table[section["country"]] or section["country"]
        if country == location["country"] and section["city"] == location["city"] then
            table.insert(same_location, section[".name"])
        elseif section["country"] == location["country"] then
            table.insert(same_country, section[".name"])
        end
    end)
    return same_location, same_country
end

function update.change_locations_if_obsolete(pre_update_locations)
    local config_name = "vpn"
    local section_name = "active"
    local replaced = false
    local interfaces = utils.get_vpn_interfaces()
    for vpn_interface, _ in pairs(interfaces) do
        local current_location = uci:get(config_name, section_name, vpn_interface)
                or uci:get(config_name, section_name, "name")
        local current_location_name = uci:get(config_name, current_location, "name")
        if not current_location_name then
            local location = pre_update_locations[current_location]
            if location then
                local same_location, same_country = update.get_similar_locations(location)
                if #same_location ~= 0 then
                    uci:set(config_name, section_name, vpn_interface, same_location[math.random(#same_location)])
                    replaced = true
                elseif #same_country ~= 0 then
                    uci:set(config_name, section_name, vpn_interface, same_country[math.random(#same_country)])
                    replaced = true
                end
            end
        end
    end
    if replaced then
        -- notify rest-api and update openvpn configs
        os.execute("kill -USR1 $(ps | grep [r]est_api | awk '{print $1}') 2>/dev/null")
        uci:save(config_name)
        uci:commit(config_name)
        for vpn_interface, tun_name in pairs(interfaces) do
            utils.apply_vpn_config(uci, vpn_interface, tun_name)
        end
        os.execute("/etc/init.d/openvpn restart")
        utils.log("Updated locations which were missing after update to their closest match")
    end
end

function update.update_vpn()
    local ovpn_template_location = "/etc/openvpn/templates/"
    utils.log("Checking if new VPN configuration is available.")
    if utils.s_download(update.config.vpn_configuration_content_sha, "/tmp/latest_vpn_configuration.content.sha") then
        local content_sha = string.gmatch(utils.get_first_line("/tmp/latest_vpn_configuration.content.sha"), "%S+")()
        if content_sha ~= update.config.current_vpn_sha then
            utils.log("Downloading new VPN configuration...")
            if utils.s_download(update.config.vpn_configuration_zip, "/tmp/vpn_configuration.zip") and
                    utils.s_download(update.config.vpn_configuration_sha, "/tmp/vpn_config_download.sha") then
                os.execute("sha256sum /tmp/vpn_configuration.zip > /tmp/vpn_config_received.sha")
                local initial_sha = string.gmatch(utils.get_first_line("/tmp/vpn_config_download.sha"), "%S+")()
                local download_sha = string.gmatch(utils.get_first_line("/tmp/vpn_config_received.sha"), "%S+")()
                if initial_sha == download_sha and
                        os.execute("unzip -o -d /tmp/potential_configs /tmp/vpn_configuration.zip") == 0 then
                    utils.log("VPN configuration available in /tmp/vpn_configuration.zip")
                    utils.log("New configuration files available in /tmp/potential_configs")

                    -- move templates and certificates
                    os.execute("mv /tmp/potential_configs/*.template "..ovpn_template_location)
                    os.execute("mv /tmp/potential_configs/*.crt /etc/openvpn")

                    -- get information from current locations if available
                    local pre_update_locations = update.get_current_locations()

                    -- delete previous templated uci entries
                    local config_name = "vpn"
                    uci:load(config_name)
                    local section = "server"
                    uci:foreach(config_name, section, function(s)
                        if uci:get(config_name, s['.name'], "template") then
                            uci:delete(config_name, s['.name'])
                        end
                    end)

                    -- add new ones from CSV
                    local successful_replacement = false
                    for line in io.lines("/tmp/potential_configs/server_list.csv") do
                        local matching_regex = "([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)"
                        local name, country, city, address, template = line:match(matching_regex)
                        if name ~= "name" then
                            local uci_name = utils.uci_characters(name)
                            uci:set(config_name, uci_name, "server")
                            uci:set(config_name, uci_name, "country", country)
                            uci:set(config_name, uci_name, "city", city)
                            uci:set(config_name, uci_name, "name", name)
                            uci:set(config_name, uci_name, "address", address)
                            uci:set(config_name, uci_name, "template", ovpn_template_location..template)
                            successful_replacement = true
                        end
                    end
                    if successful_replacement then
                        uci:save(config_name)
                        uci:commit(config_name)
                    end
                    uci:load("update")
                    uci:set("update", "active", "current_vpn_sha", content_sha)
                    uci:save("update")
                    uci:commit("update")
                    update.change_locations_if_obsolete(pre_update_locations)
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
    if utils.s_download(update.config.new_firmware_version, "/tmp/latest_firmware_version.txt") then
        local config_name = "update"
        uci:load(config_name)
        local current_version = uci:get(config_name, "version", "firmware")
        local new_version = utils.get_first_line("/tmp/latest_firmware_version.txt")
        if update.new_version_higher(current_version, new_version) then
            if utils.file_exists("/etc/update/firmware/new_firmware-"..new_version.."-sysupgrade.bin") then
                utils.log("We have already downloaded that update, finished for now.")
                uci:set(config_name, "version", "new_firmware", new_version)
                uci:save(config_name)
                uci:commit(config_name)
                return 1
            else
                utils.log("Downloading new firmware.")
                local firmware_string = string.format(update.config.new_firmware_bin, new_version)
                local sha_string = string.format(update.config.new_firmware_sha, new_version)
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
                        uci:set(config_name, "version", "new_firmware", new_version)
                        uci:save(config_name)
                        uci:commit(config_name)
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
    os.execute("uci set luci.themes.Material=/luci-static/material; "
            .."uci set luci.main.mediaurlbase=/luci-static/material; "
            .."uci commit luci")
end

function update.update_opkg()
    local upgrade_command = "PACKS=\"$(opkg list-upgradable | awk '{ printf \"%s \",$1 }')\"; "..
            "if [[ ! -z \"${PACKS}\" ]]; then "..
                "opkg install ${PACKS} &> /var/log/opkg_upgrade.log; "..
            "else "..
                "echo $'\\nNo packages to install\\n' &> /var/log/opkg_upgrade.log; "..
            "fi"
    if (update.config.use_clearnet == false) then
        utils.log("Updating opkg via .onion.")
        os.execute("opkg update > /var/log/opkg_update.log 2>&1")
        utils.log(utils.run_and_log("cat /var/log/opkg_update.log"))
        os.execute(upgrade_command)
        utils.log(utils.run_and_log("cat /var/log/opkg_upgrade.log"))
        update.restore_material_theme()
        return 0
    else
        utils.log("Updating opkg via clearnet.")
        os.execute("OPKG_CONF_DIR=/etc/opkg_clear opkg update > /var/log/opkg_update.log 2>&1")
        utils.log(utils.run_and_log("cat /var/log/opkg_update.log"))
        os.execute(upgrade_command)
        utils.log(utils.run_and_log("cat /var/log/opkg_upgrade.log"))
        update.restore_material_theme()
        return 1
    end
end

function update.update_vpn_status()
    utils.log("Checking VPN subscription status")
    local config_name = "vpn"
    local option_type = "active"
    uci:load(config_name)
    local vpn_username = uci:get(config_name, option_type, "username")
    if (vpn_username ~= nil
            and utils.s_download(update.config.vpn_status.."/"..vpn_username, "/tmp/vpn_status.json")) then
        utils.log("Got updated VPN subscription status")
        local json_content = utils.read_file("/tmp/vpn_status.json") or ""
        if string.match(json_content, ".*provider.*") ~= nil then
            local provider = utils.hack_json(json_content, "provider")
            if (provider == "wlvpn") then
                os.execute("sed '2!d' /etc/openvpn/login.auth > /tmp/vpn_password.txt")
                local vpn_password = utils.get_first_line("/tmp/vpn_password.txt")
                if vpn_password ~= "" then
                    utils.s_post(update.config.server.."/migrate_user", "application/json",
                            '{"username": "'..vpn_username:gsub('"', '\\"')..'", "password": "'
                                    ..vpn_password:gsub('"', '\\"')..'"}')
                else
                    utils.log("Unable to read password from login.auth")
                end
            end
        end
        if string.match(json_content, ".*registered.*expiry.*renewal.*") ~= nil then
            local registered = utils.hack_json(json_content, "registered")
            if (registered == "true") then
                uci:set(config_name, option_type, "registered", "true")
            elseif (registered == "false") then
                uci:set(config_name, option_type, "registered", "false")
            end
            local renewal = utils.hack_json(json_content, "renewal")
            if (renewal == "true") then
                uci:set(config_name, option_type, "renewal", "true")
            elseif (renewal == "false") then
                uci:set(config_name, option_type, "renewal", "false")
            end
            local expiry = utils.hack_json(json_content, "expiry")
            if (expiry ~= nil and expiry == "Never" or string.len(expiry) == 10 or string.len(expiry) == 11) then
                uci:set(config_name, option_type, "expiry", expiry)
            end
            uci:save(config_name)
            uci:commit(config_name)
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
    if utils.s_download(update.config.new_firmware_version, "/tmp/latest_invizbox_version.txt") then
        local config_name = "update"
        uci:load(config_name)
        local current_version = uci:get(config_name, "version", "firmware")
        utils.log("current version: "..current_version)
        local new_version = utils.get_first_line("/tmp/latest_invizbox_version.txt")
        utils.log("new version: "..new_version)
        if update.new_version_higher(current_version, new_version) then
            utils.log("new version is higher - setting it in config")
            uci:set(config_name, "version", "new_firmware", new_version)
            uci:save(config_name)
            uci:commit(config_name)
        end
    end
end

function update.update_blacklists()
    local blacklists_location = "/etc/dns_blacklist/"
    utils.log("Checking if new blacklists configuration is available.")
    if utils.s_download(update.config.blacklists_content_sha, "/tmp/latest_blacklists.content.sha") then
        local content_sha = string.gmatch(utils.get_first_line("/tmp/latest_blacklists.content.sha"), "%S+")()
        if content_sha ~= update.config.current_blacklists_sha then
            utils.log("Downloading new Blacklists...")
            if utils.s_download(update.config.blacklists_zip, "/tmp/blacklists.zip") and
                    utils.s_download(update.config.blacklists_sha, "/tmp/blacklists_download.sha") then
                os.execute("sha256sum /tmp/blacklists.zip > /tmp/blacklists_received.sha")
                local initial_sha = string.gmatch(utils.get_first_line("/tmp/blacklists_download.sha"), "%S+")()
                local download_sha = string.gmatch(utils.get_first_line("/tmp/blacklists_received.sha"), "%S+")()
                if initial_sha == download_sha and
                        os.execute("unzip -o -d /tmp/new_blacklists /tmp/blacklists.zip") == 0 then
                    utils.log("New backlists available in /tmp/new_blacklists")

                    -- delete previous blacklists
                    local config_name = "blacklists"
                    uci:load(config_name)
                    local section = "blacklist"
                    uci:foreach(config_name, section, function(s)
                        uci:delete(config_name, s['.name'])
                    end)

                    -- add new ones from CSV
                    local successful_replacement = false
                    for line in io.lines("/tmp/new_blacklists/blacklists.csv") do
                        local matching_regex = "([^,]+),([^,]+),([^,]+),([^,]+)"
                        local name, source, file, description = line:match(matching_regex)
                        if name ~= "name" then
                            local uci_name = utils.uci_characters(file:match(".*/(.*)"))
                            uci:set(config_name, uci_name, "blacklist")
                            uci:set(config_name, uci_name, "name", name)
                            uci:set(config_name, uci_name, "source", source)
                            uci:set(config_name, uci_name, "file", file)
                            uci:set(config_name, uci_name, "description", description)
                            successful_replacement = true
                        end
                    end
                    if successful_replacement then
                        uci:save(config_name)
                        uci:commit(config_name)
                    end

                    -- move blacklists
                    os.execute("mv /tmp/new_blacklists/* ".. blacklists_location)

                    uci:load("update")
                    uci:set("update", "active", "current_vpn_sha", content_sha)
                    uci:save("update")
                    uci:commit("update")
                else
                    utils.log("Invalid sha256 after download, will try again later")
                    return 1
                end
            else
                utils.log("Unable to obtain a more up to date VPN configuration, will try again later")
                return 2
            end
            os.execute("rm -rf /tmp/new_blacklists")
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

function update.update()
    -- prevent multiple executions of script in parallel (if lock is left as update is killed - only a restart or manual
    -- removal of lock file will allow for a successful run of update
    if os.execute("lock -n /var/lock/update.lock") ~= 0 then
        utils.log("Unable to obtain update lock.")
        return false
    end

    -- hacking log function here to be able to use invizboxutils with logging and yet avoid an empty log file when
    -- unable to acquire the lock above - not too clean...
    local log_file = io.open("/var/log/update.log", "w")
    utils.log = function(string)
        log_file:write(string.."\n")
        log_file:flush()
    end
    utils.log("Update started.")

    update.load_update_config()

    local notify_rest_api = false
    local config_name = "update"
    uci:load(config_name)
    if uci:get(config_name, "active", "vpn") == "true" then
        utils.log("Updating VPN status.")
        update.update_vpn_status()
        utils.log("Updating VPN locations.")

        notify_rest_api = (update.update_vpn() == true) or notify_rest_api
    end
    if uci:get(config_name, "active", "firmware") == "true" then
        utils.log("Updating firmware.")
        notify_rest_api = (update.update_firmware() == true) or notify_rest_api
    end
    if uci:get(config_name, "active", "opkg") == "true" then
        utils.log("Updating opkg packages.")
        update.update_opkg()
    end
    if uci:get(config_name, "active", "version_only") == "true" then
        utils.log("Updating version.")
        update.version_only()
    end
    if uci:get(config_name, "active", "blacklists") == "true" then
        utils.log("Updating blacklists.")
        notify_rest_api = (update.update_blacklists() == true) or notify_rest_api
    end
    -- notify rest-api if needed
    if notify_rest_api then
        os.execute("kill -USR1 $(ps | grep [r]est_api | awk '{print $1}') 2>/dev/null")
    end

    utils.log("Update complete.")
    log_file:close()
    os.execute("lock -u /var/lock/update.lock")
    return true
end

if not pcall(getfenv, 4) then
    update.update()
end

return update
