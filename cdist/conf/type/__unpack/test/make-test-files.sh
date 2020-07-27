#!/bin/sh -ex

echo test.7z > test
7z a test.7z test > /dev/null

echo test.bz2 > test
bzip2 test

echo test.gz > test
gzip test

echo test.lzma > test
lzma test

echo test.rar > test
rar a test.rar test > /dev/null

echo test.tar.bz2 > test
tar cf test.tar test
bzip2 test.tar

echo test.tar.xz > test
tar cf test.tar test
xz test.tar

echo test.tgz > test
tar cf test.tar test
gzip test.tar
mv test.tar.gz test.tgz

echo test.tar.gz > test
tar cf test.tar test
gzip test.tar

echo test.tar > test
tar cf test.tar test

echo test.xz > test
xz test

echo test.zip > test
zip test.zip test > /dev/null

rm test
