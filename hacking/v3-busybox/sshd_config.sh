#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "$0: output directory"
    exit 1
fi

dir=$1

mkdir -p "$dir/etc/ssh"
mkdir -p "$dir/root/.ssh"
mkdir -p "$dir/lib"

cat << eof > "$dir/etc/ssh/sshd_config"
# cdist generated - do not modify
PermitRootLogin without-password
eof

cat << eof > "$dir/etc/passwd"
root:x:0:0:root:/root:/bin/bash
nobody:x:99:99:nobody:/:/bin/false
eof

cat << eof > "$dir/etc/group"
root:x:0:root
nobody:x:99:
eof

# libpam not found
# /etc/ssl/openssl.cnf
# /etc/gai.conf
# no nscd socket
# /etc/nsswitch.conf
# libnss_compat.so.2
# libnss_files.so.2

# Fixes the user problem
cp /lib/libnss* "$dir/lib"

# Required by sshd
mkdir -p "$dir/var/empty"
chmod 0700 "$dir/var/empty"

#cat << eof > "$dir/etc/shadow"
#root:x:0:0:root:/root:/bin/bash
#nobody:x:1::::::
#eof

