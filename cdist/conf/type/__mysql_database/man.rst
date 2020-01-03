cdist-type__mysql_database(7)
=============================

NAME
----
cdist-type__mysql_database - Manage a MySQL database


DESCRIPTION
-----------

Create MySQL database and optionally user with all privileges.


OPTIONAL PARAMETERS
-------------------
name
   Name of database. Defaults to object id.

user
   Create user and give all privileges to database.

password
   Password for user.

state
   Defaults to present.
   If absent and user is also set, both will be removed (with privileges).


EXAMPLES
--------

.. code-block:: sh

    # just create database
    __mysql_database foo

    # create database with respective user with all privileges to database
    __mysql_database bar \
        --user name \
        --password secret


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2020 Ander Punnar. You can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.
