#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "$0 iso"
    exit 1
fi

iso=$1; shift

qemu-system-x86_64 -m 512 -boot order=cd \
    -drive=$iso,media=cdrom

