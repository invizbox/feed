#!/bin/ash

# Copyright 2021 InvizBox Ltd
#
# Licensed under the InvizBox Shared License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        https://www.invizbox.com/lic/license.txt

for vpn_interface in vpn_1 vpn_2 vpn_3 vpn_4
do
    if [ "$(uci get ipsec.${vpn_interface}.enabled)" == "1" ]; then
        if ipsec stroke statusall "${vpn_interface}" | grep -q INSTALLED; then
            ping -4 -c 1 -I "tun${vpn_interface:4}" 1.1.1.1 >/dev/null 2>&1
        else
            echo "Restarting ${vpn_interface} as the tunnel is down" >/dev/kmsg
            ipsec stroke up "${vpn_interface}"
        fi
    fi
done
