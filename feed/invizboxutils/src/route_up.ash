#!/bin/sh

# Copyright 2020 InvizBox Ltd
#
# Licensed under the InvizBox Shared License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        https://www.invizbox.com/lic/license.txt

dev_number=${dev:3}
ip route add default proto static via ${route_vpn_gateway} dev ${dev} table ${dev_number}
mkdir -p /tmp/openvpn/${dev_number}/
echo "up" > /tmp/openvpn/${dev_number}/status
