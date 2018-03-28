#!/bin/ash

if [ $# -ne 0 ] ; then
    opkg -f $1 update
else
    opkg update
fi

PACKS="$(opkg list-upgradable | awk '{ printf "%s ",$1 }')"
if [[ ! -z "$PACKS" ]] ; then 
    opkg install $PACKS &> /var/log/opkg_upgrade.log
else 
    echo $'\nNo packages to install\n' &> /var/log/opkg_upgrade.log
fi
