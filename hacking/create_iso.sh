#!/bin/sh

# FIXME: include os explorer to name preos

if [ "$#" -ne 2 ]; then
    echo "$0 dir-in iso-out"
    exit 1
fi

indir=$1; shift
iso=$1; shift

version=0.3

out=preos-${version}.iso

    # -cache-inodes \
genisoimage -r -J -l \
    -V "cdist PreOS $version" \
    -b boot/isolinux.bin -no-emul-boot -c boot.cat -boot-load-size 4 -boot-info-table \
    -o "$iso" "$indir"
