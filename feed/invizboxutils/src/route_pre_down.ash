#!/bin/sh

# Copyright 2020 InvizBox Ltd
#
# Licensed under the InvizBox Shared License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        https://www.invizbox.com/lic/license.txt

dev_number=${dev:3}
ip route del default table ${dev_number}
mkdir -p /tmp/openvpn/${dev_number}/
echo "down" > /tmp/openvpn/${dev_number}/status
