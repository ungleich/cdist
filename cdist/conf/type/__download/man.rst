cdist-type__download(7)
=======================

NAME
----
cdist-type__download - Download a file


DESCRIPTION
-----------
By default type will try to use ``wget``, ``curl`` or ``fetch``.
If download happens in target (see ``--download``) then type will
fallback to (and install) ``wget``.

If download happens in local machine, then environment variables like
``{http,https,ftp}_proxy`` etc can be used on cdist execution
(``http_proxy=foo cdist config ...``).


REQUIRED PARAMETERS
-------------------
url
   File's URL.


OPTIONAL PARAMETERS
-------------------
sum
   Checksum is used to decide if existing destination file must be redownloaded.
   By default output of ``cksum`` without filename is expected.
   Other hash formats supported with prefixes: ``md5:``, ``sha1:`` and ``sha256:``.

download
   If ``local`` (default), then download file to local storage and copy
   it to target host. If ``remote``, then download happens in target.

cmd-get
   Command used for downloading.
   Command must output to ``stdout``.
   Parameter will be used for ``printf`` and must include only one
   format specification ``%s`` which will become URL.
   For example: ``wget -O - '%s'``.

cmd-sum
   Command used for checksum calculation.
   Command output and ``--sum`` parameter must match.
   Parameter will be used for ``printf`` and must include only one
   format specification ``%s`` which will become destination.
   For example: ``md5sum '%s' | awk '{print $1}'``.

onchange
   Execute this command after download.


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


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2021 Ander Punnar. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
