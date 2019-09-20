#!/bin/sh

# echo $@
# set -x
src=$1; shift
dst=$1; shift
real_dst=$(echo $dst | sed 's,:,,')
cp -L "$src" "$real_dst"
