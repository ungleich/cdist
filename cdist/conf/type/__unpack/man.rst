cdist-type__unpack(7)
=====================

NAME
----
cdist-type__unpack - Unpack archives


DESCRIPTION
-----------
Unpack ``.tar``, ``.tgz``, ``.tar.*``, ``.7z``, ``.bz2``, ``.gz``,
``.lzma``, ``.xz``, ``.rar`` and ``.zip`` archives. Archive type is
detected by extension.

To achieve idempotency, checksum file will be created in target. See
``--sum-file`` parameter for details.


REQUIRED PARAMETERS
-------------------
destination
   Depending on archive format file or directory to where archive
   contents will be written.


OPTIONAL PARAMETERS
-------------------
sum-file
    Override archive's checksum file in target. By default
    ``XXX.cdist__unpack_sum`` will be used, where ``XXX`` is source
    archive path. This file must be kept in target's persistent storage.

tar-strip
    Tarball specific. See ``man tar`` for ``--strip-components``.

tar-extra-args
    Tarball sepcific. Append additional arguments to ``tar`` command.
    See ``man tar`` for possible arguments.


OPTIONAL BOOLEAN PARAMETERS
---------------------------
backup-destination
    By default destination file will be overwritten. In case destination
    is directory, files from archive will be added to or overwritten in
    directory. This parameter moves existing destination to
    ``XXX.cdist__unpack_backup_YYY``, where ``XXX`` is destination and
    ``YYY`` current UNIX timestamp.

preserve-archive
    Don't delete archive after unpacking.

onchange
    Execute this command after unpack.


EXAMPLES
--------

.. code-block:: sh

    __directory /opt/cpma

    require='__directory/opt/cpma' \
        __download /opt/cpma/cnq3.zip \
            --url https://cdn.playmorepromode.com/files/cnq3/cnq3-1.51.zip \
            --sum md5:46da3021ca9eace277115ec9106c5b46

    require='__download/opt/cpma/cnq3.zip' \
        __unpack /opt/cpma/cnq3.zip \
            --backup-destination \
            --preserve-archive \
            --destination /opt/cpma/server

    # example usecase for --tar-* args
    __unpack /root/strelaysrv.tar.gz \
        --preserve-archive \
        --destination /usr/local/bin \
        --tar-strip 1 \
        --tar-extra-args '--wildcards "*/strelaysrv"'


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2020 Ander Punnar. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
