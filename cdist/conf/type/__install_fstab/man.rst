cdist-type__install_fstab(7)
============================

NAME
----
cdist-type__install_fstab - generate /etc/fstab during installation


DESCRIPTION
-----------
Uses __install_generate_fstab to generate a /etc/fstab file and uploads it
to the target machine at ${prefix}/etc/fstab.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
prefix
   The prefix under which to generate the /etc/fstab file.
   Defaults to /target.


EXAMPLES
--------

.. code-block:: sh

    __install_fstab

    __install_fstab --prefix /mnt/target


SEE ALSO
--------
:strong:`cdist-type__install_generate_fstab`\ (7),
:strong:`cdist-type__install_mount`\ (7)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
