#!/bin/sh

# Copyright (C) 2015 OpenWrt.org
# Copyright 2016 InvizBox Ltd
#
# Licensed under the InvizBox Shared License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        https://www.invizbox.com/lic/license.txt

. /bin/ledcontrol.ash
. /bin/mtdutils.ash

write_wifi_password () {
    password_file="/export/${mntpnt}/wifi_password.txt"
    if [ -f "${password_file}" ]; then
        logger "Found a wifi password file"
        password=$(head -c 16 "${password_file}")
        write_string_to_mtd2 ${password} 16 65520
        case $? in
            1) logger "password string wasn't ASCII" ;;
            2) logger "password string wasn't the correct length" ;;
            3) logger "written password didn't match the one from file. Fix this by starting this procedure over with a new file!" ;;
            4) logger "could not unlock mtd0 device - not writing to it" ;;
            0) logger "The password was successfully written to the device"
               echo ${password} >> "/export/${mntpnt}/written_wifi_pass.txt"
               sed -i '1d' "${password_file}"
               led_wifi_green_quick_flashing
               ;;
        esac
    fi
}

write_vpn_credentials () {
    vpn_file="/export/${mntpnt}/vpn_credentials.txt"
    if [ -f "${vpn_file}" ]; then
        logger "Found a VPN credentials file"
        read vpn_username vpn_password < "${vpn_file}"
        write_string_to_mtd2 ${vpn_username} 64 65432
        case $? in
            1) logger "VPN username string wasn't ASCII"
               return 1
               ;;
            2) logger "VPN username string wasn't the correct length"
               return 1
               ;;
            3) logger "written VPN username didn't match the one from file. Fix this by starting this procedure over with a new file!"
               return 1
               ;;
            4) logger "could not unlock mtd0 device - not writing to it"
               return 1
               ;;
            0) logger "The VPN username was successfully written to the device" ;;
        esac
        write_string_to_mtd2 ${vpn_password} 24 65496
        case $? in
            1) logger "VPN password string wasn't ASCII"
               return 1
               ;;
            2) logger "VPN password string wasn't the correct length"
               return 1
               ;;
            3) logger "written VPN password didn't match the one from file. Fix this by starting this procedure over with a new file!"
               return 1
               ;;
            4) logger "could not unlock mtd0 device - not writing to it"
               return 1
               ;;
            0) logger "The VPN password was successfully written to the device"
               echo ${vpn_username} ${vpn_password} >> "/export/${mntpnt}/written_vpn_cred.txt"
               sed -i '1d' "${vpn_file}"
               led_wifi_red_quick_flashing
               ;;
        esac
    fi
}

# 0 yes blockdevice handles this - 1 no it is not there
blkdev=`dirname ${DEVPATH}`
basename=`basename ${blkdev}`
device=`basename ${DEVPATH}`

if [ ${basename} != "block" ] && [ -z "${device##sd*}" ] ; then
    islabel=`blkid /dev/${device} | grep -q LABEL ; echo $?`
    if [ ${islabel} -eq 0 ] ; then
        mntpnt=`blkid /dev/${device} |sed 's/.*LABEL="\(.*\)" UUID.*/\1/'`
    else
        mntpnt=${device}
    fi
    case "${ACTION}" in
        add)
            mkdir -p "/export/${mntpnt}"
            # Set APM value for automatic spin down
            /sbin/hdparm -B 127 /dev/${device}
            # Try to be gentle on solid state devices
            mount -o rw,noatime,discard /dev/${device} "/export/${mntpnt}"
            write_wifi_password
            write_vpn_credentials
            sync
        ;;
        remove)
            # Once the device is removed, the /dev entry disappear. We need mountpoint
            mountpoint=`mount |grep /dev/${device} | sed 's/.* on \(.*\) type.*/\1/' | sed 's/\\\040/ /'`
            umount -l "${mountpoint}"
        ;;
    esac
fi
