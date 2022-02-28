#!/bin/sh

# Copyright 2021 InvizBox Ltd
# https://www.invizbox.com/lic/license.txt

uci_commit_reload() {
    /sbin/uci commit
    rm /var/run/led.state # avoid flash
    /etc/init.d/led reload
}

led_set_off() {
    /sbin/uci set system.$1.default='1'
    /sbin/uci set system.$1.trigger='none'
    /sbin/uci set system.$1.delayon=
    /sbin/uci set system.$1.delayoff=
    uci_commit_reload
}

led_set_quick_flashing() {
    /sbin/uci set system.$1.default='1'
    /sbin/uci set system.$1.trigger='timer'
    /sbin/uci set system.$1.delayon='100'
    /sbin/uci set system.$1.delayoff='500'
    uci_commit_reload
}

led_quick_flashing() {
    led_set_quick_flashing blue
}

led_off() {
    led_set_off blue
}

