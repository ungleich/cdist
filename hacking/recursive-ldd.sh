#!/bin/sh
# Nico Schottelius
# Fri May  1 17:31:50 CEST 2015

# [18:09] wurzel:.cdist-ruag% ldd /usr/bin/ls | sed -e 's/=>//' -e 's/(.*//' | awk '{ if(NF == 2) { print $2 } else { print $1 } }'

PATH=/bin:/sbin:/usr/bin:/usr/sbin

pkg="

bin_list="fdisk mount"

for bin in command_list; do

done


exit 0


bin=$1

list=""
new_list=$(objdump -p /usr/bin/ls | awk '$1 ~ /NEEDED/ { print $2 }')

[18:16] wurzel:.cdist-ruag% ldconfig -p | grep 'libBrokenLocale.so.1$' | sed 's/.* => //'


for new_item in $new_list; do
    

done

ldconfig -p | 
