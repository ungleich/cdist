cdist-type__install_generate_fstab(7)
=====================================

NAME
----
cdist-type__install_generate_fstab - generate /etc/fstab during installation


DESCRIPTION
-----------
Generates a /etc/fstab file from information retrieved from
__install_mount definitions.


REQUIRED PARAMETERS
-------------------
destination
   The path where to store the generated fstab file.
   Note that this is a path on the server, where cdist is running, not the target host.


OPTIONAL PARAMETERS
-------------------
None


BOOLEAN PARAMETERS
-------------------
uuid
   use UUID instead of device in fstab 


EXAMPLES
--------

.. code-block:: sh

    __install_generate_fstab --destination /path/where/you/want/fstab

    __install_generate_fstab --uuid --destination /path/where/you/want/fstab


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2012 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
