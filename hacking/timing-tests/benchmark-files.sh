#!/bin/sh

num=50000
dsthost=localhost

tmp=$(mktemp -d)
remote_tmp=${tmp}-remote

cd "$tmp"

create_files() {
    i=0
    while [ $i -lt $num ]; do
        echo $i > file-${i}
        i=$((i+1))
    done
}

delete_remote() {
    ssh "${dsthost}" "rm -rf ${remote_tmp}"
}


tar_remote() {
    cd "${tmp}"
    tar c . | ssh "${dsthost}" "mkdir ${remote_tmp}; cd ${remote_tmp}; tar x"
}

cdist_remote()
{
    (
        while [ $i -lt $num ]; do
            echo __file ${remote_tmp}/file-${i} --source "${tmp}/file-${i}"
            i=$((i+1))
        done
    ) | cdist config -i - -vv "${dsthost}"

}

cdist_remote_parallel()
{
    (
        while [ $i -lt $num ]; do
            echo __file ${remote_tmp}/file-${i} --source "${tmp}/file-${i}"
            i=$((i+1))
        done
    ) | cdist config -j10 -i - -vv "${dsthost}"

}

echo "Creating ${num} files"
time create_files

echo "scping files"
time scp -r "${tmp}" "${dsthost}:$remote_tmp" >/dev/null

echo "delete remote"
time delete_remote

echo "taring files"
time tar_remote

echo "delete remote"
time delete_remote

echo "cdisting files"
time cdist_remote

echo "delete remote"
time delete_remote

echo "cdisting files (parallel)!"
time cdist_remote

echo "delete remote"
time delete_remote

echo "delete local"
rm -rf "$tmp"
