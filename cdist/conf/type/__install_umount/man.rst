cdist-type__install_umount(7)
=============================

NAME
----
cdist-type__install_umount - umount target directory


DESCRIPTION
-----------
This cdist type allows you to recursively umount the given target directory.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
target
   the mount point to umount. Defaults to object_id


EXAMPLES
--------

.. code-block:: sh

    __install_umount /target


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
