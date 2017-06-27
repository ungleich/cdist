cdist-type__chroot_mount(7)
===========================

NAME
----
cdist-type__chroot_mount - mount a chroot


DESCRIPTION
-----------
Mount and prepare a chroot for running commands within it.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
manage-resolv-conf
    manage /etc/resolv.conf inside the chroot.
    Use the value of this parameter as the suffix to save a copy
    of the current /etc/resolv.conf to /etc/resolv.conf.$suffix.
    This is used by the __chroot_umount type to restore the initial
    file content when unmounting the chroot.


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

    __chroot_mount /path/to/chroot

    __chroot_mount /path/to/chroot \
      --manage-resolv-conf "some-known-string"


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2012-2017 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
