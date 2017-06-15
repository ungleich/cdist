cdist-type__daemontools(7)
==========================

NAME
----
cdist-type__daemontools - Install daemontools


DESCRIPTION
-----------
Install djb daemontools and (optionally) an init script.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
from-package
   Package to install. Must be compatible with the original daemontools. Example: daemontools-encore. Default: daemontools.

BOOLEAN PARAMETERS
------------------
install-init-script
   Add an init script and set it to start on boot.

EXAMPLES
--------

.. code-block:: sh

    __daemontools --from-package daemontools-encore  # if you prefer

SEE ALSO
--------
:strong:`cdist-type__daemontools_service`\ (7)

AUTHORS
-------
Kamila Součková <kamila--@--ksp.sk>

COPYING
-------
Copyright \(C) 2017 Kamila Součková. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
