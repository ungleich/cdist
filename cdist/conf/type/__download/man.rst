cdist-type__download(7)
=======================

NAME
----
cdist-type__download - Download file to local storage and copy it to target host


DESCRIPTION
-----------
You must use persistent storage in target host for destination file
(``$__object_id``) because it will be used for checksum calculation
in order to decide if file must be downloaded.


REQUIRED PARAMETERS
-------------------
url
   URL from which to download the file.

sum
   Checksum of downloaded file.


OPTIONAL PARAMETERS
-------------------
cmd-get
   Command used for downloading.
   Default is ``wget -O- '%s'``.
   Command must output to ``stdout``.

cmd-sum
   Command used for checksum calculation.
   Default is ``md5sum '%s' | awk '{print $1}'``.
   Command output and ``--sum`` parameter must match.


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
            --move-existing-destination \
            --destination /opt/cpma/server


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2020 Ander Punnar. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
