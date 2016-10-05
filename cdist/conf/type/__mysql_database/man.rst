cdist-type__mysql_database(7)
=============================

NAME
----
cdist-type__mysql_database - Manage a MySQL database


DESCRIPTION
-----------
This cdist type allows you to install a MySQL database.


REQUIRED PARAMETERS
-------------------
None.

OPTIONAL PARAMETERS
-------------------
name
   The name of the database to install
   defaults to the object id

user
   A user that should have access to the database

password
   The password for the user who manages the database


EXAMPLES
--------

.. code-block:: sh

    __mysql_database "cdist" --name "cdist" --user "myuser" --password "mypwd"


AUTHORS
-------
Benedikt Koeppel <code@benediktkoeppel.ch>


COPYING
-------
Copyright \(C) 2012 Benedikt Koeppel. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
