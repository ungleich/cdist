cdist-type__install_config(7)
=============================

NAME
----
cdist-type__install_config - run cdist config as part of the installation


DESCRIPTION
-----------
This cdist type allows you to run cdist config as part of the installation.
It does this by using a custom __remote_{copy,exec} prefix which runs
cdist config against the /target chroot on the remote host.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
chroot
   where to chroot before running grub-install. Defaults to /target.


EXAMPLES
--------

.. code-block:: sh

    __install_config

    __install_config --chroot /mnt/somewhere


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
