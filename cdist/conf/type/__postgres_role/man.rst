cdist-type__postgres_role(7)
============================

NAME
----
cdist-type__postgres_role - Manage postgres roles


DESCRIPTION
-----------
This cdist type allows you to create or drop postgres roles.


OPTIONAL PARAMETERS
-------------------
state
    Either "present" or "absent", defaults to "present"

All other parameters map directly to the corresponding postgres createrole
parameters.

password

BOOLEAN PARAMETERS
------------------
All parameter map directly to the corresponding postgres createrole
parameters.

login
createdb
createrole
superuser
inherit

EXAMPLES
--------

.. code-block:: sh

    __postgres_role myrole

    __postgres_role myrole --password 'secret'

    __postgres_role admin --password 'very-secret' --superuser

    __postgres_role dbcustomer --password 'bla' --createdb


SEE ALSO
--------
:strong:`cdist-type__postgres_database`\ (7)

postgresql documentation at:
<http://www.postgresql.org/docs/current/static/sql-createrole.html>.


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
