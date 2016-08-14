cdist-type__qemu_img(7)
=======================

NAME
----
cdist-type__qemu_img - Manage VM disk images


DESCRIPTION
-----------
The qemu-img program is used to create qemu images for
qemu and (qemu-)kvm.



OPTIONAL PARAMETERS
-------------------
state
    Either "present" or "absent", defaults to "present"
size
    Size of the image in qemu-img compatible units.

    Required if state is "present".


EXAMPLES
--------

.. code-block:: sh

    # Create a 50G size image
    __qemu_img /home/services/kvm/vm/myvmname/system-disk --size 50G

    # Remove image
    __qemu_img /home/services/kvm/vm/myoldvm/system-disk --state absent


SEE ALSO
--------
:strong:`qemu-img`\ (1)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2012-2014 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
