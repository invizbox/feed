#!/bin/sh

# Copyright 2021 InvizBox Ltd
#
# Licensed under the InvizBox Shared License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#		https://www.invizbox.com/lic/license.txt

for line_num in $(iptables -t nat --line-numbers --list PREROUTING | grep 'captive' | awk '{print $1}')
do
	LINES="$line_num $LINES"
done
for line in $LINES
do
	iptables -t nat -D PREROUTING $line
done
unset LINES

for line_num in $(iptables --line-numbers --list FORWARD | grep 'captive' | awk '{print $1}')
do
	LINES="$line_num $LINES"
done
for line in $LINES
do
	iptables -D FORWARD $line
done
unset LINES

ip rule del table main priority 0
echo "false" > /tmp/currently-captive
