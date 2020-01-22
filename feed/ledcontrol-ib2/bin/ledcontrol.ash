#!/bin/sh

#-- Copyright 2019 InvizBox Ltd
#-- https://www.invizbox.com/lic/license.txt
#-- Control LED states for easy config using UCI

uci_commit_reload() {
    /sbin/uci commit
    rm /var/run/led.state # avoid flash
    /etc/init.d/led reload
}

led_set_off() {
    /sbin/uci set system.$1.trigger='none'
    /sbin/uci set system.$1.delayon=
    /sbin/uci set system.$1.delayoff=
    uci_commit_reload
}

led_set_heartbeat() {
    /sbin/uci set system.$1.trigger='heartbeat'
    uci_commit_reload
}

led_set_slow_flashing() {
    /sbin/uci set system.$1.trigger='timer'
    /sbin/uci set system.$1.delayon='100'
    /sbin/uci set system.$1.delayoff='5000'
    uci_commit_reload
}

led_set_quick_flashing() {
    /sbin/uci set system.$1.trigger='timer'
    /sbin/uci set system.$1.delayon='100'
    /sbin/uci set system.$1.delayoff='500'
    uci_commit_reload
}

led_set_solid() {
    /sbin/uci set system.$1.trigger='default-on'
    uci_commit_reload
}

led_lock_off() {
    led_set_off led_lock
}

led_lock_heartbeat() {
    led_set_heartbeat led_lock
}

led_lock_quick_flashing() {
    led_set_quick_flashing led_lock
}

led_lock_on() {
    led_set_solid led_lock
}

led_globe_off() {
    led_set_off led_globe
}

led_globe_heartbeat() {
    led_set_heartbeat led_globe
}

led_globe_quick_flashing() {
    led_set_quick_flashing led_globe
}

led_globe_on() {
    led_set_solid led_globe
}

led_info_off() {
    led_set_off led_info
}

led_info_heartbeat() {
    led_set_heartbeat led_info
}

led_info_slow_flashing() {
    led_set_slow_flashing led_info
}

led_info_quick_flashing() {
    led_set_quick_flashing led_info
}

led_info_on() {
    led_set_solid led_info
}
