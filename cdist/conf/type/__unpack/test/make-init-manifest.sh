#!/bin/sh -e

p="$( pwd )"
d=/tmp/cdist__unpack_test

echo 'export CDIST_ORDER_DEPENDENCY=1'

echo "__directory $d"

find "$p" -name 'test.*' -and -not -name '*.cdist__unpack_sum' \
    | sort \
    | while read -r l
do
    n="$( basename "$l" )"

    printf '__unpack %s --destination %s/%s\n' \
        "$l" \
        "$d" \
        "$n"
done

echo "__clean_path $p --pattern '.+/test\..+'"
