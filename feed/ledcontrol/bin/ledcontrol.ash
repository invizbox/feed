#!/bin/sh

# /lib/led_funcs.sh bash
#-- Copyright 2016 InvizBox Ltd
#-- https://www.invizbox.com/lic/license.txt
#-- Control LED states for easy config using UCI 

#function to set the WiFi led green and solid
led_wifi_green_solid() {
    led_set_off red 
    led_set_solid green
}

#function to set the WiFi led green and flashing
led_wifi_green_flashing() {
    led_set_off red 
    led_set_flashing green
}

#function to set the WiFi led green and quick flashing
led_wifi_green_quick_flashing() {
    led_set_off red 
    led_set_quick_flashing green
}

#function to set the WiFi led orange and solid
led_wifi_orange_solid() {
    led_set_solid red 
    led_set_solid green
}

#function to set the WiFi led orange and flashing
led_wifi_orange_flashing() {
    led_set_flashing red 
    led_set_flashing green
}

#function to set the WiFi led red and solid
led_wifi_red_solid() {
    led_set_solid red 
    led_set_off green
}

#function to set the WiFi led red and flashing
led_wifi_red_flashing() {
    led_set_flashing red 
    led_set_off green
}

#function to set the WiFi led red and quick flashing
led_wifi_red_quick_flashing() {
    led_set_off green
    led_set_quick_flashing red
}

led_wifi_off() {
    led_set_off green                
    led_set_off red                
}

#function to set leds off
led_set_off() {
    /sbin/uci set system.$1.default='0'
    /sbin/uci set system.$1.trigger='none'
    /sbin/uci set system.$1.delayon=
    /sbin/uci set system.$1.delayoff=
    uci_commit_reload
}

#function to set leds flashing
led_set_flashing() {
    /sbin/uci set system.$1.default='1'
    /sbin/uci set system.$1.trigger='heartbeat'
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
    /sbin/uci set system.$1.default='1'
    /sbin/uci set system.$1.trigger='defaulton'
    uci_commit_reload
}

uci_commit_reload() {
    /sbin/uci commit
    /etc/init.d/led reload
}

