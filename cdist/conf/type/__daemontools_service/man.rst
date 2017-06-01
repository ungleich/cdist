cdist-type__daemontools_service(7)
==================================

NAME
----
cdist-type__daemontools_service - Create a daemontools-compatible service dir.


DESCRIPTION
-----------
Create a directory structure compatible with daemontools-like service management.

Note that svc must be present on the target system.

The object ID will be used as the service name.

REQUIRED PARAMETERS
-------------------
None.

OPTIONAL PARAMETERS
-------------------
run
   Command to run. exec-ing and stderr redirection will be added. One of run, run-file must be specified.

   Example: `my-program`

run-file
   File to save as <servicedir>/run. One of run, run-file must be specified.

   Example:

.. code-block:: sh

    #!/bin/sh
    exec 2>&1
    exec my_program


log-run
   Command to run for log consumption. Default: `multilog t ./main`

servicedir
   Directory to install into. Default: `/service`

BOOLEAN PARAMETERS
------------------
None.

EXAMPLES
--------

.. code-block:: sh

    require="__daemontools" __daemontools_service prometheus --run "setuidgid prometheus $GOBIN/prometheus $FLAGS"


SEE ALSO
--------
:strong:`cdist-type__daemontools`\ (7)


AUTHORS
-------
Kamila Součková <kamila--@--ksp.sk>

COPYING
-------
Copyright \(C) 2017 Kamila Součková. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
