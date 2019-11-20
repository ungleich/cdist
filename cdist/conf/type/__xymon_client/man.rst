cdist-type__xymon_client(7)
===========================

NAME
----
cdist-type__xymon_client - Install the Xymon client


DESCRIPTION
-----------
This cdist type installs the Xymon client and configures it to report with
FQDN.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
state
   'present', 'absent', defaults to 'present'.

servers
   One or more IP addresses (space separated) of the Xymon server(s) to report
   to. While DNS-names are ok it is discouraged, defaults to 127.0.0.1.


BOOLEAN PARAMETERS
------------------
msgcache
    Enable xymon `msgcache`. Note: XYMONSERVER has to be `127.0.0.1` for using
    `msgcache` (see `msgcache (8)` of the xymon documentation for details).

EXAMPLES
--------

.. code-block:: sh

    # minimal, report to 127.0.0.1
    __xymon_client

    # specify server:
    __xymon_client --servers "192.168.1.1"

    # activate `msgcache` for passive client:
    __xymon_client --msgcache


SEE ALSO
--------
:strong:`cdist__xymon_server`\ (7), :strong:`xymon`\ (7), :strong:`msgcache`\ (8)


AUTHORS
-------
Thomas Eckert <tom--@--it-eckert.de>


COPYING
-------
Copyright \(C) 2018-2019 Thomas Eckert. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
