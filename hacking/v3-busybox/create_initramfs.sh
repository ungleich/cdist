#!/bin/sh
set -ex


initramfs_dir=$(mktemp -d /tmp/cdist-preos.XXXXXXX)
# initramfs_dir=$1

for dir in bin sbin etc proc sys newroot usr/bin usr/sbin; do
    mkdir -p ${initramfs_dir}/$dir
done
touch ${initramfs_dir}/etc/mdev.conf

cp init "${initramfs_dir}/init"
cp $(which busybox) "${initramfs_dir}/bin"

for link in sh mount; do
    ln -fs busybox "${initramfs_dir}/bin/$link"
done

cd "${initramfs_dir}"

# Add Arch Linux initramfs with kernel modules included
zcat /boot/initramfs-linux-fallback.img | cpio -i

# TODO:
# - ssh
# - various mkfs
# - libs

# Create new initramfs
find . | cpio -H newc -o | gzip

# echo ${initramfs_dir}
rm -rf "${initramfs_dir}"

exit 0
