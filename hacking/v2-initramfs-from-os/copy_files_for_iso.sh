#!/bin/sh

set -ex

testdir=./iso-root-dir

# Create base
rm -rf "$testdir"
mkdir "$testdir"

# Copy binaries

# Copy kernel
mkdir -p "$testdir/boot"
cp /boot/vmlinuz-linux "$testdir/boot/kernel"
cp /boot/initramfs-linux-fallback.img "$testdir/boot/initramfs"

# Create iso
genisoimage -v -V "cdist preos v0.1" \
    -cache-inodes -J -l  \
    -r -no-emul-boot \
    -boot-load-size 4 -b isolinux.bin -c boot.cat -o cdist-preos.iso iso

