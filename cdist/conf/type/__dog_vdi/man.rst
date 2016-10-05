cdist-type__dog_vdi(7)
======================

NAME
----
cdist-type__dog_vdi - Manage Sheepdog VM images


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
:strong:`qemu`\ (1), :strong:`dog`\ (8)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2014 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
