cdist-type__mysql_privileges(7)
===============================

NAME
----
cdist-type__mysql_privileges - Manage MySQL privileges


DESCRIPTION
-----------

Grant and revoke privileges of MySQL user.


REQUIRED PARAMETERS
-------------------
database
   Name of database.

User
   Name of user.


OPTIONAL PARAMETERS
-------------------
privileges
   Defaults to "all".

table
   Defaults to "*".

host
   Defaults to localhost.

state
   "present" grants and "absent" revokes. Defaults to present.


EXAMPLES
--------

.. code-block:: sh

    __mysql_privileges user-to-db --database db --user user


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2020 Ander Punnar. You can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.
