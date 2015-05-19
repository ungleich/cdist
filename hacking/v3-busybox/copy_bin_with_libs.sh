#!/bin/sh
# Nico Schottelius
# Fri May  1 17:31:50 CEST 2015

# [18:09] wurzel:.cdist-ruag% ldd /usr/bin/ls | sed -e 's/=>//' -e 's/(.*//' | awk '{ if(NF == 2) { print $2 } else { print $1 } }'

PATH=/bin:/sbin:/usr/bin:/usr/sbin

#bin_list="udevadm bash fdisk mount syslinux umount rm mv"
bin_list="udevadm fdisk"

libs=$(mktemp /tmp/cdist-preos-libs.XXXXXXXXXXXXX)

for bin in bin_list; do


done

rm -f "$libs"

# lfs
## ldd /bin/$f | sed "s/\t//" | cut -d " " -f1 >> $unsorted

exit 0


bin=$1

list=""
new_list=$(objdump -p /usr/bin/ls | awk '$1 ~ /NEEDED/ { print $2 }')

[18:16] wurzel:.cdist-ruag% ldconfig -p | grep 'libBrokenLocale.so.1$' | sed 's/.* => //'


for new_item in $new_list; do
    

done

ldconfig -p | 
