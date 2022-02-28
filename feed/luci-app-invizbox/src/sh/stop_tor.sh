#!/bin/sh

kill -9 $(ps | grep '/usr/sbin/[t]or' | cut -d ' ' -f 2)
