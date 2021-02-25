#!/bin/sh

# Copyright 2019 InvizBox Ltd
# https://www.invizbox.com/lic/license.txt

. /bin/ledcontrol.ash
. /bin/mtdutils.sh

write_wifi_password () {
    password_file="/export/${mntpnt}/wifi_password.txt"
    if [ -f "${password_file}" ]; then
        logger "Found a wifi password file"
        # a WiFi password has to be between 8 and 63 printable characters
        password=$(head -n 1 "${password_file}" | tr -d '\n')
        validate_string_ascii "${password}"
        if [ ${#password} -lt 8 ]; then
            return 2
        fi
        if [ ${#password} -gt 63 ]; then
            return 3
        fi
        echo -n ${password} > /private/wifi_password.txt
        echo ${password} >> "/export/${mntpnt}/written_wifi_pass.txt"
        sed -i '1d' "${password_file}"
        return 0
    fi
    return 1
}

write_vpn_credentials () {
    vpn_file="/export/${mntpnt}/vpn_credentials.txt"
    if [ -f "${vpn_file}" ]; then
        logger "Found a VPN credentials file"
        read vpn_username vpn_password plan < "${vpn_file}"
        echo -n "${vpn_username} ${vpn_password} ${plan}" > /private/vpn_credentials.txt
        echo ${vpn_username} ${vpn_password} ${plan} >> "/export/${mntpnt}/written_vpn_cred.txt"
        sed -i '1d' "${vpn_file}"
        return 0
    fi
    return 1
}

write_ipsec_credentials () {
    ipsec_file="/export/${mntpnt}/ipsec_credentials.txt"
    if [ -f "${ipsec_file}" ]; then
        logger "Found an IPSec credentials file"
        read ipsec_username ipsec_password < "${ipsec_file}"
        echo -n "${ipsec_username} ${ipsec_password}" > /private/ipsec_credentials.txt
        echo ${ipsec_username} ${ipsec_password} >> "/export/${mntpnt}/written_ipsec_cred.txt"
        sed -i '1d' "${ipsec_file}"
        return 0
    fi
    return 1
}

perform_reset() {
    reset_file="/export/${mntpnt}/reset.txt"
    if [ -f "${reset_file}" ]; then
        logger "Found a reset file - resetting"
        mv "/export/${mntpnt}/reset.txt" "/export/${mntpnt}/reset_done.txt"
        led_info_quick_flashing
        firstboot -y
        reboot
    fi
}

# 0 yes blockdevice handles this - 1 no it is not there
blkdev=`dirname ${DEVPATH}`
basename=`basename ${blkdev}`
device=`basename ${DEVPATH}`

if [ ${basename} != "block" ] && [ -z "${device##sd*}" ]; then
    islabel=`blkid /dev/${device} | grep -q LABEL ; echo $?`
    if [ ${islabel} -eq 0 ]; then
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
            flash_password=$?
            write_vpn_credentials
            flash_vpn=$?
            write_ipsec_credentials
            flash_vpn=$(( $? || ${flash_vpn} ))
            sync
            if [ "${flash_password}" -eq "0" ] && [ "${flash_vpn}" -eq "0" ]; then
                led_info_on
                turn_info_led_off=1
            elif [ "${flash_password}" -eq "0" ]; then
                led_info_quick_flashing
                turn_info_led_off=1
            elif [ "${flash_vpn}" -eq "0" ]; then
                led_info_heartbeat
                turn_info_led_off=1
            fi
            sleep 5
            if [ "${turn_info_led_off}" -eq "1" ]; then
                led_info_off
            fi
            perform_reset
        ;;
        remove)
            # Once the device is removed, the /dev entry disappear. We need mountpoint
            mountpoint=`mount |grep /dev/${device} | sed 's/.* on \(.*\) type.*/\1/' | sed 's/\\\040/ /'`
            umount -l "${mountpoint}"
        ;;
    esac
fi
