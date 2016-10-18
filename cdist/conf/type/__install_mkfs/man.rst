cdist-type__install_mkfs(7)
===========================

NAME
----
cdist-type__install_mkfs - build a linux file system


DESCRIPTION
-----------
This cdist type is a wrapper for the mkfs command.


REQUIRED PARAMETERS
-------------------
type
   The filesystem type to use. Same as used with mkfs -t.


OPTIONAL PARAMETERS
-------------------
device
   defaults to object_id

options
   file system-specific options to be passed to the mkfs command

blocks
   the number of blocks to be used for the file system


EXAMPLES
--------

.. code-block:: sh

    # reiserfs /dev/sda5
    __install_mkfs /dev/sda5 --type reiserfs

    # same thing with explicit device
    __install_mkfs whatever --device /dev/sda5 --type reiserfs

    # jfs with journal on /dev/sda2
    __install_mkfs /dev/sda1 --type jfs --options "-j /dev/sda2"


SEE ALSO
--------
:strong:`mkfs`\ (8)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
