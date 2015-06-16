#!/bin/sh

rm -rf preos
mkdir -p preos/boot

initramfs=preos/boot/initramfs

./create_initramfs.sh > "$initramfs"
./add_kernel_isolinux.sh preos
./copy_bin_with_libs.sh preos
./create_iso.sh preos preos.iso

exit 0
