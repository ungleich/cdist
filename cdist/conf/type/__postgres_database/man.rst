cdist-type__postgres_database(7)
================================

NAME
----
cdist-type__postgres_database - Create/drop postgres databases


DESCRIPTION
-----------
This cdist type allows you to create or drop postgres databases.


OPTIONAL PARAMETERS
-------------------
state
   Either 'present' or 'absent', defaults to 'present'.

owner
   Specifies the database user who will own the new database.

encoding
   Specifies the character encoding scheme to be used in this database.

lc-collate
   Specifies the LC_COLLATE setting to be used in this database.

lc-ctype
   Specifies the LC_CTYPE setting to be used in this database.

template
   Specifies the template database from which to build this database.


EXAMPLES
--------

.. code-block:: sh

    __postgres_database mydbname --owner mydbusername


SEE ALSO
--------
:strong:`cdist-type__postgres_role`\ (7)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
