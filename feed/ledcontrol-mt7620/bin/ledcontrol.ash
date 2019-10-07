#!/bin/sh

# /lib/led_funcs.sh bash
#-- Copyright 2016 InvizBox Ltd
#-- https://www.invizbox.com/lic/license.txt
#-- Control LED states for easy config using UCI 

#function to set the led solid
led_solid() {
    led_set_solid blue
}

#function to set the led flashing
led_flashing() {
    led_set_flashing blue
}

#function to set the led quick flashing
led_quick_flashing() {
    led_set_quick_flashing blue
}

led_off() {
    led_set_off blue
}

#function to set leds off
led_set_off() {
    /sbin/uci set system.$1.default='1'
    /sbin/uci set system.$1.trigger='none'
    /sbin/uci set system.$1.delayon=
    /sbin/uci set system.$1.delayoff=
    uci_commit_reload
}

#function to set leds flashing
led_set_flashing() {
    /sbin/uci set system.$1.default='1'
    /sbin/uci set system.$1.trigger='timer'
    /sbin/uci set system.$1.delayon='250'
    /sbin/uci set system.$1.delayoff='250'
    uci_commit_reload
}

#function to set leds quick flashing
led_set_quick_flashing() {
    /sbin/uci set system.$1.default=1
    /sbin/uci set system.$1.trigger='timer'
    /sbin/uci set system.$1.delayon='100'
    /sbin/uci set system.$1.delayoff='500'
    uci_commit_reload
}

#function to set leds solid
led_set_solid() {
    /sbin/uci set system.$1.default='0'
    /sbin/uci set system.$1.trigger='none'
    /sbin/uci set system.$1.delayon=
    /sbin/uci set system.$1.delayoff=
    uci_commit_reload
}

uci_commit_reload() {
    /sbin/uci commit
    /etc/init.d/led reload
}
