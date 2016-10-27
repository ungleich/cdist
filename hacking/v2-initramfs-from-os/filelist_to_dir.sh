#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "$0 outdir"
    exit 1
fi

outdir=$1; shift

mkdir -p "$outdir"

while read file; do
    if [ -d "$file" ]; then
        mkdir -p "$outdir$file"
    else
        cp --preserve=mode,links "$file" "$outdir$file"
    fi
done
