#!/bin/sh

# Copyright 2017 InvizBox Ltd
#
# Licensed under the InvizBox Shared License;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#        https://www.invizbox.com/lic/license.txt

validate_string_ascii () {
    # keeping only non printable characters and checking if any left
    ascii_string=$(echo $1 | grep '[^ -~]')
    if [ -n "${ascii_string}" ]; then 
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
    mtd unlock /dev/mtd2
    if [ $? -ne 0 ]; then
        exit 4
    fi
    awk_cmd="awk '{printf \"%-${size}s\", \$0}'"
    string_with_spaces=$(echo "${string}" | eval ${awk_cmd} )
    validate_string_ascii "${string_with_spaces}"
    if [ $? -ne 0 ]; then
        return 1
    fi
    validate_string_exact "${string_with_spaces}" ${size}
    if [ $? -ne 0 ]; then
        return 2
    fi
    echo "${string_with_spaces}" > /tmp/tmp_string.txt && dd if=/dev/mtd2 of=/tmp/mtd2 && dd if=/tmp/tmp_string.txt of=/tmp/mtd2 bs=1 count=${size} seek=${offset} conv=notrunc && mtd unlock /dev/mtd2 && mtd write /tmp/mtd2 /dev/mtd2 && rm /tmp/tmp_string.txt /tmp/mtd2
    written_string=$(dd if=/dev/mtd2 bs=1 skip=${offset} count=${size})
    if [[ "${string}" != "${written_string}" ]]; then
        return 3
    fi
}
