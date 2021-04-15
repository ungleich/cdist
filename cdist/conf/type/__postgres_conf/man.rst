cdist-type__postgres_conf(7)
============================

NAME
----
cdist-type__postgres_conf - Alter PostgreSQL configuration


DESCRIPTION
-----------
Configure a running PostgreSQL server using ``ALTER SYSTEM``.


REQUIRED PARAMETERS
-------------------
value
   The value to set (can be omitted if ``--state`` is set to ``absent``).


OPTIONAL PARAMETERS
-------------------
state
   ``present`` or ``absent``.
   Defaults to ``present``.


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

   # set timezone
   __postgres_conf timezone --value Europe/Zurich

   # reset maximum number of concurrent connections to default (normally 100)
   __postgres_conf max_connections --state absent


SEE ALSO
--------
None.


AUTHORS
-------
Beni Ruef (bernhard.ruef--@--ssrq-sds-fds.ch)
Dennis Camera (dennis.camera--@--ssrq-sds-fds.ch)


COPYING
-------
Copyright \(C) 2019-2021 SSRQ (www.ssrq-sds-fds.ch).
You can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.
