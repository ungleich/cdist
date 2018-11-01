#!/bin/sh

# Addapt to your env.
CDIST_PATH="$CDIST_PATH:./docs/dev/python-types/conf"
export CDIST_PATH
TARGET_HOST=185.203.112.26
env | grep CDIST_PATH

for streams in ' ' '-S'
do
    for x in sh py
    do
        printf "[%s] Removing old foobar* files\\n" "$x"
        printf -- "----------------\\n"
        ssh root@${TARGET_HOST} 'rm foobar*; rm dummy*'
        printf "[%s] Listing foobar* files\\n" "$x"
        printf -- "----------------\\n"
        ssh root@${TARGET_HOST} 'ls foobar* dummy*'
        printf "[%s] Running cdist config, streams: %s\\n" "$x" "$streams"
        printf -- "----------------\\n"
        ./bin/cdist config -P ${streams} -v -i ./docs/dev/python-types/conf/manifest/${x}init  -- ${TARGET_HOST}
        printf "[%s] Listing foobar* files\\n" "$x"
        printf -- "----------------\\n"
        ssh root@${TARGET_HOST} 'ls foobar* dummy*'
        ./bin/cdist config -P ${streams} -v -i ./docs/dev/python-types/conf/manifest/${x}init  -- ${TARGET_HOST}
    done
done
