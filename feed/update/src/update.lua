#! /usr/bin/env lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- updates VPN configuration and firmware

local utils = require "invizboxutils"
local fs = require("nixio.fs")
local uci_mod = require("uci")
local uci = uci_mod.cursor()
local uci_etc = uci_mod.cursor("/etc")
local json = require("luci.jsonc")

local update = {}
update.config = {}

function update.load_update_config(use_clearnet)
    update.config.use_clearnet = use_clearnet or false
    local config_name = "updateinfo"
    local network = "onion"
    uci_etc:load(config_name)
    if update.config.use_clearnet == true then
        network = "clearnet"
    end
    update.config.vpn_configuration = uci_etc:get(config_name, network, "vpn_configuration")
    update.config.vpn_configuration_sha = uci_etc:get(config_name, network, "vpn_configuration_sha")
    update.config.vpn_configuration_content_sha = uci_etc:get(config_name, network, "vpn_configuration_content_sha")
    update.config.new_firmware_version = uci_etc:get(config_name, network, "new_firmware_version")
    update.config.new_firmware = uci_etc:get(config_name, network, "new_firmware")
    update.config.new_firmware_sha = uci_etc:get(config_name, network, "new_firmware_sha")
    update.config.vpn_status = uci_etc:get(config_name, network, "vpn_status")
    update.config.current_content_sha = uci_etc:get(config_name, "active", "current_content_sha")
end

function update.update_vpn()
    local ovpn_template_location = "/etc/openvpn/templates/"
    utils.log("Checking if new VPN configuration is available.")
    if utils.success(utils.download(update.config.vpn_configuration_content_sha, "/tmp/latest_vpn_configuration.content.sha")) then
        local content_sha = string.gmatch(utils.get_first_line("/tmp/latest_vpn_configuration.content.sha"), "%S+")()
        if content_sha ~= update.config.current_content_sha then
            utils.log("Downloading new VPN configuration...")
            if utils.success(utils.download(update.config.vpn_configuration, "/tmp/vpn_configuration.zip")) and
                    utils.success(utils.download(update.config.vpn_configuration_sha, "/tmp/vpn_config_download.sha")) then
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
                        local name, country, city, address, template =  line:match("([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")
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
                    uci_etc:load("updateinfo")
                    uci_etc:set("updateinfo", "active", "current_content_sha", content_sha)
                    uci_etc:save("updateinfo")
                    uci_etc:commit("updateinfo")
                else
                    utils.log("Invalid sha256 after download, will try again later")
                    return 1
                end
            else
                utils.log("Unable to obtain a more up to date VPN configuration, will try again later")
                return 2
            end
            os.execute("rm -rf /tmp/potential_configs")
            utils.log("Successfully updated template, certificate and VPN uci settings")
            return true
        else
            utils.log("We already have the most up to date VPN configuration")
            return 3
        end
    else
        utils.log("Unable to get a content SHA for the latest VPN configuration, will try again later")
        return 4
    end
end

function update.new_version_higher(old_version, new_version)
    local old_major, old_minor, old_patch = old_version:match"([^.]*).([^.]*).(.*)"
    local new_major, new_minor, new_patch = new_version:match"([^.]*).([^.]*).(.*)"
    utils.log("["..new_major.."]")
    if tonumber(old_major) == nil or tonumber(new_major) == nil or tonumber(old_minor) == nil or tonumber(new_minor) == nil or tonumber(old_patch) == nil or tonumber(new_patch) == nil then
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
    if utils.success(utils.download(update.config.new_firmware_version, "/tmp/latest_firmware_version.txt")) then
        local config_name = "updateinfo"
        uci_etc:load(config_name)
        local current_version = uci_etc:get(config_name, "version", "firmware")
        local new_version = utils.get_first_line("/tmp/latest_firmware_version.txt")
        if update.new_version_higher(current_version, new_version) then
            if utils.file_exists("/tmp/update/firmware/InvizBox-Go-"..new_version.."-sysupgrade.bin") then
                utils.log("We have already downloaded that update, finished for now.")
                uci_etc:set(config_name, "version", "new_firmware", new_version)
                uci_etc:save(config_name)
                uci_etc:commit(config_name)
                return 1
            else
                utils.log("Downloading new firmware.")
                if utils.success(utils.download(string.format(update.config.new_firmware, new_version), "/tmp/firmware_download.bin")) and
                        utils.success(utils.download(string.format(update.config.new_firmware_sha, new_version), "/tmp/firmware_download.sha")) then
                    os.execute("sha256sum /tmp/firmware_download.bin > /tmp/firmware_received.sha")
                    local initial_sha = string.gmatch(utils.get_first_line("/tmp/firmware_download.sha"), "%S+")()
                    local download_sha = string.gmatch(utils.get_first_line("/tmp/firmware_received.sha"), "%S+")()
                    if initial_sha == download_sha then
                        os.execute("rm -rf /tmp/update/firmware; mkdir -p /tmp/update/firmware && mv /tmp/firmware_download.bin /tmp/update/firmware/InvizBox-Go-"..new_version.."-sysupgrade.bin")
                        utils.log("New firmware now available at /tmp/update/firmware/InvizBox-Go-"..new_version.."-sysupgrade.bin")
                        uci_etc:set(config_name, "version", "new_firmware", new_version)
                        uci_etc:save(config_name)
                        uci_etc:commit(config_name)
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
        return 0
    else
        utils.log("Updating opkg via clearnet.")
        os.execute("opkg -f /etc/opkg_clearnet.conf update > /var/log/opkg_update.log  2>&1")
        utils.log(utils.run_and_log("cat /var/log/opkg_update.log"))
        os.execute(upgrade_command)
        utils.log(utils.run_and_log("cat /var/log/opkg_upgrade.log"))
        return 1
    end
end

function update.update_vpn_status()
    utils.log("Checking VPN subscription status")
    local config_name = "vpn"
    local option_type = "active"
    uci:load(config_name)
    local vpn_username = uci:get(config_name, option_type, "username")
    if (vpn_username ~= nil and utils.success(utils.download(update.config.vpn_status.."/"..vpn_username, "/tmp/vpn_status.json"))) then
        utils.log("Got updated VPN subscription status")
        local json_tree = json.parse(fs.readfile("/tmp/vpn_status.json") or "")
        if (json_tree and json_tree.status) then
            local registered = json_tree.status.registered
            if (registered == true) then
                uci:set(config_name, option_type, "registered", "true")
            elseif (registered == false) then
                uci:set(config_name, option_type, "registered", "false")
            end
            local renewal = json_tree.status.renewal
            if (renewal == true) then
                uci:set(config_name, option_type, "renewal", "true")
            elseif (renewal == false) then
                uci:set(config_name, option_type, "renewal", "false")
            end
            local expiry = json_tree.status.expiry
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
        utils.log("Unable to retrieve VPN subscription status this time, will try again later.")
        return 2
    end
end

function update.check_network()
    utils.log("Checking if .onion is accessible.")
    if utils.success(utils.download(update.config.vpn_configuration_content_sha, "/tmp/latest_vpn_configuration.content.sha")) then
        utils.log(".onion is accessible.")
        return 1
    else
        utils.log(".onion is inaccessible, switch to clearnet.")
        update.load_update_config(true)
        return 0
    end
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
    update.check_network()
    update.update_vpn_status()
    local success = update.update_vpn() == true
    success = update.update_firmware() == true and success
    success = update.update_opkg() == true and success
    if success then
        uci_etc:load("updateinfo")
        uci_etc:set("updateinfo", "active", "last_successful_update", os.time())
        uci_etc:save("updateinfo")
        uci_etc:commit("updateinfo")
        os.execute("lock -u /var/lock/update.lock")
        return true
    end
    utils.log("Update complete.")
    log_file:close()
    os.execute("lock -u /var/lock/update.lock")
    return false
end

if not pcall(getfenv, 4) then
    update.update()
end

return update
