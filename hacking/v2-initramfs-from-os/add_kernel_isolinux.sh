#!/bin/sh

# FIXME: Write cdist type / explorer that finds
# package for a file, distro independent

if [ "$#" -ne 1 ]; then
    echo "$0 dir-out"
    exit 1
fi

dir=$1; shift
boot=$dir/boot

mkdir -p "$boot"
cp /boot/vmlinuz-linux                      \
    /boot/initramfs-linux-fallback.img      \
    /usr/lib/syslinux/bios/isolinux.bin     \
    "$boot"

cp /usr/lib/syslinux/bios/ldlinux.c32      \
    "$dir"

cat > "$dir/isolinux.cfg" << eof
default preos
label   preos
title   cdist PreOS
linux   /boot/vmlinuz-linux
initrd  /boot/initramfs-linux-fallback.img
eof
