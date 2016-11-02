#!/bin/sh

# echo $@
# set -x

chroot="$1"; shift

script=$(mktemp "${chroot}/tmp/chroot-${0##*/}.XXXXXXXXXX")
trap cleanup INT TERM EXIT
cleanup() {
   [ $__cdist_debug ] || rm "$script"
}

echo "#!/bin/sh -l" > "$script"
echo "$@" >> "$script"
chmod +x "$script"

relative_script="${script#$chroot}"

# ensure PATH is setup
export PATH=$PATH:/bin:/usr/bin:/sbin:/usr/sbin

# run in chroot
chroot "$chroot" "$relative_script"
