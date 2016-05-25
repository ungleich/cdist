cdist-type__dog_vdi(7)
======================
Manage Sheepdog VM images

Nico Schottelius <nico-cdist--@--schottelius.org>


DESCRIPTION
-----------
The dog program is used to create images for sheepdog
to be used in qemu.


OPTIONAL PARAMETERS
-------------------
state
    Either "present" or "absent", defaults to "present"
size
    Size of the image in "dog vdi" compatible units.

    Required if state is "present".



EXAMPLES
--------

.. code-block:: sh

    # Create a 50G size image
    __dog_vdi nico-privat.sky.ungleich.ch --size 50G

    # Create a 50G size image (more explicit)
    __dog_vdi nico-privat.sky.ungleich.ch --size 50G --state present

    # Remove image
    __dog_vdi nico-privat.sky.ungleich.ch --state absent

    # Remove image - keeping --size is ok
    __dog_vdi nico-privat.sky.ungleich.ch --size 50G --state absent


SEE ALSO
--------
- `cdist-type(7) <cdist-type.html>`_
- dog(8)
- qemu(1)


COPYING
-------
Copyright \(C) 2014 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
