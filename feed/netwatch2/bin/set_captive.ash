#!/bin/sh

# Copyright 2021 InvizBox Ltd
#
# Licensed under the InvizBox Shared License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        https://www.invizbox.com/lic/license.txt

iptables -t nat -I PREROUTING -s 10.153.147.0/24 ! -d 10.153.147.1/21 -p tcp --syn -j ACCEPT -m comment --comment "captive"
iptables -t nat -I PREROUTING -p tcp --dport 53 -j REDIRECT --to-ports 54 -m comment --comment "captive"
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 54 -m comment --comment "captive"
iptables -I FORWARD -o wlan0 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT -m comment --comment "captive"
iptables -I FORWARD -i wlan0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -m comment --comment "captive"
ip rule add table main priority 0
echo "true" > /tmp/currently-captive
