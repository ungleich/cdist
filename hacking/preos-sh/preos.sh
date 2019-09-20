#!/bin/sh

TARGET_DIR="$1"
PXE_BOOT_DIR="$2"

debootstrap --include=openssh-server --arch=amd64 stable $TARGET_DIR
chroot $TARGET_DIR /usr/bin/apt-get update

# Configure the OS
cdist config -i init --remote-exec remote-exec.sh --remote-copy remote-exec.sh $TARGET_DIR

# Cleanup chroot
chroot $TARGET_DIR /usr/bin/apt-get autoclean
chroot $TARGET_DIR /usr/bin/apt-get clean
chroot $TARGET_DIR /usr/bin/apt-get autoremove

# Output pxe files
cp $TARGET_DIR/boot/vmlinuz-* $PXE_BOOT_DIR/kernel

cd $TARGET_DIR
find . -print0 | cpio --null -o --format=newc | gzip -9 > $PXE_BOOT_DIR/initramfs

cat << EOF > $PXE_BOOT_DIR/pxelinux.cfg/default
DEFAULT preos
LABEL preos
KERNEL kernel
INITRD initramfs
EOF

cp $TARGET_DIR/usr/lib/PXELINUX/pxelinux.0 $PXE_BOOT_DIR/pxelinux.0
cp $TARGET_DIR/usr/lib/syslinux/modules/bios/ldlinux.c32 $PXE_BOOT_DIR/ldlinux.c32
