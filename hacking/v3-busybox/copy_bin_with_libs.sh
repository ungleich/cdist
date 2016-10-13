#!/bin/sh
# Nico Schottelius
# Fri May  1 17:31:50 CEST 2015


PATH=/bin:/sbin:/usr/bin:/usr/sbin

if [ "$#" -ne 1 ]; then
    echo "$0 dir-out"
    exit 1
fi


out_dir=$1

#bin_list="udevadm bash fdisk mount syslinux umount rm mv"
bin_list="udevadm fdisk"

libs=$(mktemp /tmp/cdist-preos-libs.XXXXXXXXXXXXX)

mkdir -p "$out_dir/bin" "$out_dir/lib"

(   
    for bin in $bin_list; do
        src=$(which "$bin")
        cp "$src" "$out_dir/bin"
    
        ldd "$src" | sed -e 's/=>//' -e 's/(.*//' | awk '{ if(NF == 2) { print $2 } else { print $1 } }'
    done
) | sort | uniq > "$libs"


while read lib; do
    if echo $lib | grep '^/'; then
        # echo "Copying fqdn lib $lib ..."
        cp "$lib" "$out_dir/lib"
    else
        echo "How to copy $lib ?"
    fi
done < "$libs"


rm -f "$libs"

exit 0


bin=$1

# Not used alternatives
# new_list=$(objdump -p /usr/bin/ls | awk '$1 ~ /NEEDED/ { print $2 }')
# ldconfig -p | grep 'libBrokenLocale.so.1$' | sed 's/.* => //'


for new_item in $new_list; do
    

done

ldconfig -p | 
