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
   Add an init script and set it to start on boot. Default yes.

EXAMPLES
--------

.. code-block:: sh

    __daemontools --from-package daemontools-encore  # if you prefer

SEE ALSO
--------
cdist-type__daemontools_service

AUTHORS
-------
Kamila Součková <kamila--@--ksp.sk>
