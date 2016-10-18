cdist-type__install_reset_disk(7)
=================================

NAME
----
cdist-type__install_reset_disk - reset a disk


DESCRIPTION
-----------
Remove partition table.
Remove all lvm labels.
Remove mdadm superblock.


REQUIRED PARAMETERS
-------------------
None

OPTIONAL PARAMETERS
-------------------
None


EXAMPLES
--------

.. code-block:: sh

    __install_reset_disk /dev/sdb


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2012 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
