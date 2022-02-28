#!/bin/sh

# Copyright 2021 InvizBox Ltd
# https://www.invizbox.com/lic/license.txt

. /etc/device_info

if [ "${DEVICE_PRODUCT}" == "InvizBox" ]; then
	. /bin/ledcontrol_original.ash
elif [ "${DEVICE_PRODUCT}" == "InvizBox Go" ]; then
	. /bin/ledcontrol_go.ash
elif [ "${DEVICE_PRODUCT}" == "InvizBox 2" ]; then
	. /bin/ledcontrol_2.ash
fi

led_restarting() {
	if [ "${DEVICE_PRODUCT}" == "InvizBox Go" ]; then
		led_wifi_green_quick_flashing
	elif [ "${DEVICE_PRODUCT}" == "InvizBox 2" ]; then
		led_info_quick_flashing
	fi
}

led_boot_start() {
	if [ "${DEVICE_PRODUCT}" == "InvizBox" ]; then
		led_quick_flashing
	elif [ "${DEVICE_PRODUCT}" == "InvizBox Go" ]; then
		led_wifi_green_heartbeat
	elif [ "${DEVICE_PRODUCT}" == "InvizBox 2" ]; then
		led_info_heartbeat
	fi
}

led_boot_end() {
	if [ "${DEVICE_PRODUCT}" == "InvizBox" ]; then
		led_off
	elif [ "${DEVICE_PRODUCT}" == "InvizBox Go" ]; then
		led_wifi_off
	elif [ "${DEVICE_PRODUCT}" == "InvizBox 2" ]; then
		led_info_off
	fi
}

led_password_written() {
	if [ "${DEVICE_PRODUCT}" == "InvizBox Go" ]; then
		led_wifi_green_quick_flashing
	elif [ "${DEVICE_PRODUCT}" == "InvizBox 2" ]; then
		led_info_quick_flashing
	fi
}

led_credentials_written() {
	if [ "${DEVICE_PRODUCT}" == "InvizBox Go" ]; then
		led_wifi_red_quick_flashing
	elif [ "${DEVICE_PRODUCT}" == "InvizBox 2" ]; then
		led_info_heartbeat
	fi
}

led_password_and_credentials_written() {
	if [ "${DEVICE_PRODUCT}" == "InvizBox 2" ]; then
		led_info_on
	fi
}
