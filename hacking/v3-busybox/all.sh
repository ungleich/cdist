#!/bin/sh

rm -rf preos
mkdir -p preos/boot

./generate.sh > preos/boot/initramfs
./add_kernel_isolinux.sh preos

