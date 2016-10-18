cdist-type__install_mount(7)
============================

NAME
----
cdist-type__install_mount - mount filesystems in the installer


DESCRIPTION
-----------
Mounts filesystems in the installer. Collects data to generate /etc/fstab.


REQUIRED PARAMETERS
-------------------
device
   the device to mount


OPTIONAL PARAMETERS
-------------------
dir
   where to mount device. Defaults to object_id.

options
   mount options passed to mount(8) and used in /etc/fstab

type
   filesystem type passed to mount(8) and used in /etc/fstab.
   If type is swap, 'dir' is ignored.
   Defaults to the filesystem used in __install_mkfs for the same 'device'.

prefix
   the prefix to prepend to 'dir' when mounting in the installer.
   Defaults to /target.


EXAMPLES
--------

.. code-block:: sh

    __install_mount slash --dir / --device /dev/sda5 --options noatime
    require="__install_mount/slash" __install_mount /boot --device /dev/sda1
    __install_mount swap --device /dev/sda2 --type swap
    require="__install_mount/slash" __install_mount /tmp --device tmpfs --type tmpfs


SEE ALSO
--------
:strong:`cdist-type__install_mkfs`\ (7),
:strong:`cdist-type__install_mount_apply` (7)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
