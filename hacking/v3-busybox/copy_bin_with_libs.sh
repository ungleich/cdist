#!/bin/sh
# Nico Schottelius
# Fri May  1 17:31:50 CEST 2015


PATH=/bin:/sbin:/usr/bin:/usr/sbin

if [ "$#" -ne 1 ]; then
    echo "$0 dir-out"
    exit 1
fi


out_dir=$1

# TODO:
# - various mkfs 

#bin_list="udevadm bash fdisk mount syslinux umount rm mv"
bin_list="udevadm fdisk sshd ssh-keygen"

# debug tools
bin_list="$bin_list strace less"

libs=$(mktemp /tmp/cdist-preos-libs.XXXXXXXXXXXXX)

(   
    for bin in $bin_list; do
        src=$(which "$bin")
        cp "$src" "$out_dir/bin"
    
        ldd "$src" | sed -e 's/=>//' -e 's/(.*//' | awk '{ if(NF == 2) { print $2 } else { print $1 } }'
    done
) | sort | uniq > "$libs"


while read lib; do
    if echo $lib | grep -q '^/'; then
        # echo "Copying fqdn lib $lib ..."
        cp "$lib" "$out_dir/lib"
    fi
done < "$libs"

rm -f "$libs"
