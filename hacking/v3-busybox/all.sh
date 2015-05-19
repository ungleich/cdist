#!/bin/sh

rm -rf preos
mkdir -p preos/boot

./create_initramfs.sh > preos/boot/initramfs
./add_kernel_isolinux.sh preos
./create_iso.sh preos preos.iso

