#!/bin/sh

# FIXME: include os explorer to name preos

indir=./iso

version=0.3
out=preos-${version}.iso

genisoimage -r  -V "cdist preos v0.2" \
    -cache-inodes -J -l  \
    -no-emul-boot \
    -boot-load-size 4 -b isolinux.bin -c boot.cat \
    -o cdist-preos.iso $indir
