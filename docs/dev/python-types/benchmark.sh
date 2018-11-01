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

manifest() {
    bytes=$(echo "$1 * 1024" | bc)
    echo "head -c ${bytes} /dev/random | __file$2 /root/foo$3.bin --source - --mode 0640 --owner root --group root"
}

verbosity="-vv" #"-vvv"
i=0
while [ "$i" -lt "$N" ]
do
    if [ "$N" -ne 1 ]
    then
        printf "iteration %d\\n" "$i"
    fi
    printf "shinit clean state...\\n"
    ssh root@${TARGET_HOST} 'rm foo$i.bin;'
    manifest 50 "" $i | ./bin/cdist config "${verbosity}" -P -i - ${TARGET_HOST}

    printf "pyinit clean state...\\n"
    ssh root@${TARGET_HOST} 'rm foo$i.bin;'
    manifest 50 '_py' $i | ./bin/cdist config "${verbosity}" -P -i - ${TARGET_HOST}

    printf "shinit present state...\\n"
    manifest 50 "" $i | ./bin/cdist config "${verbosity}" -P -i - ${TARGET_HOST}

    printf "pyinit present state...\\n"
    manifest 50 '_py' $i | ./bin/cdist config "${verbosity}" -P -i - ${TARGET_HOST}

    i=$((i + 1))
done
