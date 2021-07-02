cdist-type__download(7)
=======================

NAME
----
cdist-type__download - Download a file


DESCRIPTION
-----------
By default type will try to use ``curl``, ``fetch`` or ``wget``.
If download happens in target (see ``--download``) then type will
fallback to (and install) ``wget``.

If download happens in local machine, then environment variables like
``{http,https,ftp}_proxy`` etc can be used on cdist execution
(``http_proxy=foo cdist config ...``).

To change downloaded file's owner, group or permissions, use ``require='__download/path/to/file' __file ...``.


REQUIRED PARAMETERS
-------------------
url
   File's URL.


OPTIONAL PARAMETERS
-------------------
destination
   Downloaded file's destination in target. If unset, ``$__object_id`` is used.

sum
   Supported formats: ``cksum`` output without file name, MD5, SHA1 and SHA256.

   Type tries to detect hash format with regexes, but prefixes
   ``cksum:``, ``md5:``, ``sha1:`` and ``sha256:`` are also supported.

   Checksum have two purposes - state check and post-download verification.
   In state check, if destination checksum mismatches, then content of URL
   will be downloaded to temporary file. If downloaded temporary file's
   checksum matches, then it will be moved to destination (overwritten).

   For local downloads it is expected that usable utilities for checksum
   calculation exist in the system.

download
   If ``local`` (default), then file is downloaded to local storage and copied
   to target host. If ``remote``, then download happens in target.

   For local downloads it is expected that usable utilities for downloading
   exist in the system. Type will try to use ``curl``, ``fetch`` or ``wget``.

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
            --sum 46da3021ca9eace277115ec9106c5b46

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
