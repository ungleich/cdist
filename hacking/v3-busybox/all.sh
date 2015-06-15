#!/bin/sh

rm -rf preos
mkdir -p preos/boot

initramfs=preos/boot/initramfs

./create_initramfs.sh > "$initramfs"
./add_kernel_isolinux.sh preos
./copy_bin_with_libs.sh preos
./create_iso.sh preos preos.iso

exit 0

run_earlyhook() {
    kmod static-nodes --format=tmpfiles --output=/run/tmpfiles.d/kmod.conf
    systemd-tmpfiles --prefix=/dev --create --boot
    /usr/lib/systemd/systemd-udevd --daemon --resolve-names=never
    udevd_running=1
}   
    
run_hook() {
    msg ":: Triggering uevents..."
    udevadm trigger --action=add --type=subsystems
    udevadm trigger --action=add --type=devices
    udevadm settle
}           
        
run_cleanuphook() {
    udevadm control --exit
    udevadm info --cleanup-db
}      
