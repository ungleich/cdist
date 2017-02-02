cdist-type__install_bootloader_grub(7)
======================================

NAME
----
cdist-type__install_bootloader_grub - install grub2 bootloader on given disk


DESCRIPTION
-----------
This cdist type allows you to install grub2 bootloader on given disk.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
device
   The device to install grub to. Defaults to object_id

chroot
   where to chroot before running grub-install. Defaults to /target.


EXAMPLES
--------

.. code-block:: sh

    __install_bootloader_grub /dev/sda

    __install_bootloader_grub /dev/sda --chroot /mnt/foobar


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
