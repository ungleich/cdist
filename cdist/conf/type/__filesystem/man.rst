cdist-type__filesystem(7)
=========================

NAME
----
cdist-type__filesystem - Create Filesystems.


DESCRIPTION
-----------
This cdist type allows you to create filesystems on devices.

If the device is mounted on target, it refuses to do anything.

If the device has a filesystem other then the specified and/or
the label is not correct, it only makes a new filesystem
if you have specified --force option.


REQUIRED PARAMETERS
-------------------
fstype
    Filesystem type, for example 'ext3', 'btrfs' or 'xfs'.



OPTIONAL PARAMETERS
-------------------
device
    Blockdevice for filesystem, Defaults to object_id.
    On linux, it can be any lsblk accepted device notation.

    |
    | For example:
    |    /dev/sdx
    |    or /dev/disk/by-xxxx/xxx
    |    or /dev/mapper/xxxx

label
   Label which should be applied on the filesystem.

mkfsoptions
   Additional options which are inserted to the mkfs.xxx call.


BOOLEAN PARAMETERS
------------------
force
   Normally, this type does nothing if a filesystem is found
   on the target device. If you specify force, it's formatted
   if the filesystem type or label differs from parameters.
   Warning: This option can easily lead into data loss!

MESSAGES
--------
filesystem <fstype> on <device> \: <discoverd device> created
   Filesystem was created on <discoverd device>


EXAMPLES
--------

.. code-block:: sh

    # Ensures that device /dev/sdb is formatted with xfs
    __filesystem /dev/sdb --fstype xfs --label Testdisk1
    # The same thing with btrfs and disk spezified by pci path to disk 1:0 on vmware
    __filesystem dev_sdb --fstype btrfs --device /dev/disk/by-path/pci-0000:0b:00.0-scsi-0:0:0:0 --label Testdisk2
    # Make sure that a multipath san device has a filesystem ...
    __filesystem dev_sdb --fstype xfs --device /dev/mapper/360060e80432f560050202f22000023ff --label Testdisk3


AUTHORS
-------
Daniel Heule <hda--@--sfs.biz>


COPYING
-------
Copyright \(C) 2016 Daniel Heule. Free use of this software is
granted under the terms of the GNU General Public License version 3 or any later version (GPLv3+).
