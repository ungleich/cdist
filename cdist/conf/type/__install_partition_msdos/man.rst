cdist-type__install_partition_msdos(7)
======================================

NAME
----
cdist-type__install_partition_msdos - creates msdos partitions


DESCRIPTION
-----------
This cdist type allows you to create msdos paritions.


REQUIRED PARAMETERS
-------------------
type
   the partition type used in fdisk (such as 82 or 83) or "extended"


OPTIONAL PARAMETERS
-------------------
partition
   defaults to object_id

bootable
   mark partition as bootable, true or false, defaults to false

size
   the size of the partition (such as 32M or 15G, whole numbers
   only), '+' for remaining space, or 'n%' for percentage of remaining
   (these should only be used after all specific partition sizes are
   specified). Defaults to +.


EXAMPLES
--------

.. code-block:: sh

    # 128MB, linux, bootable
    __install_partition_msdos /dev/sda1 --type 83 --size 128M --bootable true
    # 512MB, swap
    __install_partition_msdos /dev/sda2 --type 82 --size 512M
    # 100GB, extended
    __install_partition_msdos /dev/sda3 --type extended --size 100G
    # 10GB, linux
    __install_partition_msdos /dev/sda5 --type 83 --size 10G
    # 50% of the free space of the extended partition, linux
    __install_partition_msdos /dev/sda6 --type 83 --size 50%
    # rest of the extended partition, linux
    __install_partition_msdos /dev/sda7 --type 83 --size +


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
