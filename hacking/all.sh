#!/bin/sh

set -e

dir=./iso
iso=preos.iso

./filelist_from_package.sh | ./filelist_to_dir.sh "$dir"
echo "MISSING: copy libraries" >&2
./add_kernel_isolinux.sh "$dir"
./create_iso.sh "$dir" "$iso"
