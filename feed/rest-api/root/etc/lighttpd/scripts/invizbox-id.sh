#!/bin/sh

radio0_path=$(uci get wireless.radio0.path)
mac_address=$(cat "/sys/devices/${radio0_path}/ieee80211/phy"*[0]"/macaddress" || "unknown")
invizbox_id=$(echo $mac_address | tr -d '\n' | sha256sum | cut -c1-16)

echo 'var.invizboxId="'${invizbox_id}'"'
