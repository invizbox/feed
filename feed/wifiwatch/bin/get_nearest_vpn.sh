#!/bin/ash

# Copyright 2016 InvizBox Ltd
#
# Licensed under the InvizBox Shared License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        https://www.invizbox.com/lic/license.txt

vpn_location=$(wget -qO- https://invizbox.com/cgi-bin/nearest)

if [ "${vpn_location}" != "" ]; then
    find /etc/openvpn/configs -name "*${vpn_location}*" > /tmp/find.txt
    file_size=$(wc -w /tmp/find.txt | awk '{print $1}')
    random_number=$(lua -e "math.randomseed(os.time()) print(math.random($file_size))")
    vpn_entry=$(head -n ${random_number} /tmp/find.txt | tail -1)
    vpn_name=$(echo ${vpn_entry} | cut -d'.' -f 1 | cut -d'-' -f 4)$(echo ${vpn_entry} | cut -d'.' -f 1 | cut -d'-' -f 5)
    uci set vpn.active.name=${vpn_name}
    uci commit vpn
    cp ${vpn_entry} /etc/openvpn/openvpn.conf
fi
