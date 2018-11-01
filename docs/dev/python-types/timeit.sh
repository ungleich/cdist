#!/bin/sh

# Addapt to your env.
CDIST_PATH="$CDIST_PATH:./docs/dev/python-types/conf"
export CDIST_PATH
TARGET_HOST=185.203.112.26

if [ $# -eq 0 ]
then
    N=1
else
    N=$1
fi

i=0
while [ "$i" -lt "$N" ]
do
    if [ "$N" -ne 1 ]
    then
        printf "iteration %d\\n" "$i"
    fi
    printf "shinit clean state...\\n"
    ssh root@${TARGET_HOST} 'rm foobar*; rm dummy*;'

    time ./bin/cdist config -vv -P -i ./docs/dev/python-types/conf/manifest/shinit ${TARGET_HOST}
    printf "pyinit clean state...\\n"
    ssh root@$${TARGET_HOST} 'rm foobar*; rm dummy*;'
    time ./bin/cdist config -vv -P -i ./docs/dev/python-types/conf/manifest/pyinit ${TARGET_HOST}

    printf "shinit present state...\\n"
    time ./bin/cdist config -vv -P -i ./docs/dev/python-types/conf/manifest/shinit ${TARGET_HOST}

    printf "pyinit present state...\\n"
    time ./bin/cdist config -vv -P -i ./docs/dev/python-types/conf/manifest/pyinit ${TARGET_HOST}
    i=$((i + 1))
done
