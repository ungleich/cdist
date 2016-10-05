cdist-type__mount(7)
====================

NAME
----
cdit-type__mount - Manage filesystem mounts


DESCRIPTION
-----------
Manage filesystem mounts either via /etc/fstab or manually.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
device
   device to mount at path, defaults to 'none'. see mount(8)

dump
   value for the dump field in fstab. see fstab(5)
   defaults to 0.

   This parameter is ignored, if the nofstab parameter is given.

options
   comma separated string of options, see mount(8)

pass
   value for the pass field in fstab. see fstab(5)
   defaults to 0.

   This parameter is ignored, if the nofstab parameter is given.

path
   mount point where to mount the device, see mount(8).
   Defaults to __object_id

state
   either present or absent. Defaults to present.

type
   vfstype, see mount(8)


BOOLEAN PARAMETERS
------------------
nofstab
   do not manage an entry in /etc/fstab


EXAMPLES
--------

.. code-block:: sh

    __mount /some/dir \
       --device /dev/sdc3 \
       --type xfs \
       --options "defaults,ro"
       --dump 0 \
       --pass 1

    __mount /var/lib/one \
       --device mfsmount \
       --type fuse \
       --options "mfsmaster=mfsmaster.domain.tld,mfssubfolder=/one,nonempty,_netdev"


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2014 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
