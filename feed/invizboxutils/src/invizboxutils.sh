#!/bin/sh

# Copyright 2021 InvizBox Ltd
#
# Licensed under the InvizBox Shared License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        https://www.invizbox.com/lic/license.txt

version () {
    if [ "$1" == "@VERSION@" ]; then
        printf '999999999'
    else
        printf '%03d%03d%03d' $(echo "$1" | tr '.' ' ');
    fi
}

validate_string_ascii () {
    # keeping only non printable characters and checking if any left
    non_ascii=$(echo $1 | LC_COLLATE=C grep '[^ -~]')
    if [ -n "${non_ascii}" ]; then
        return 1
    fi
}

validate_string_exact () {
    string=$1
    size=$2
    if [ ${#string} -ne ${size} ]; then
        return 1
    fi
}

write_string_to_mtd2 (){
    string=$1
    size=$2
    offset=$3
    string_name=${4:-provided}

    if ! mtd unlock /dev/mtd2; then
    	logger "could not unlock mtd2 device - not writing to it"
        return 4
    fi
    awk_cmd="awk '{printf \"%-${size}s\", \$0}'"
    string_with_spaces=$(echo "${string}" | eval ${awk_cmd} )
    if ! validate_string_ascii "${string_with_spaces}"; then
    	logger "${string_name} string wasn't ASCII"
        return 1
    fi
    if ! validate_string_exact "${string_with_spaces}" ${size}; then
    	logger "${string_name} wasn't the correct length"
        return 2
    fi
    echo "${string_with_spaces}" > /tmp/tmp_string.txt && dd if=/dev/mtd2 of=/tmp/mtd2 && dd if=/tmp/tmp_string.txt of=/tmp/mtd2 bs=1 count=${size} seek=${offset} conv=notrunc && mtd unlock /dev/mtd2 && mtd write /tmp/mtd2 /dev/mtd2 && rm /tmp/tmp_string.txt /tmp/mtd2
    written_string=$(dd if=/dev/mtd2 bs=1 skip=${offset} count=${size})
    if [ "${string}" != "${written_string}" ]; then
    	logger "written ${string_name} didn't match the one from file"
        return 3
    fi
    logger "${string_name} was successfully written to the device"
}
