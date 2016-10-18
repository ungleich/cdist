#!/bin/sh

# FIXME: distro specific kernel location

if [ "$#" -ne 1 ]; then
    echo "$0 dir-out"
    exit 1
fi

dir=$1; shift
boot=$dir/boot

mkdir -p "$boot"
cp /boot/vmlinuz-linux "$boot/linux"
cp /usr/lib/syslinux/bios/isolinux.bin "$boot"
cp /usr/lib/syslinux/bios/ldlinux.c32 "$dir"

cat > "$dir/isolinux.cfg" << eof
default preos
label   preos
title   cdist PreOS
linux   /boot/linux
initrd  /boot/initramfs
eof
