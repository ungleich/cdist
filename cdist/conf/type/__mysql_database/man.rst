cdist-type__mysql_database(7)
=============================
Manage a MySQL database

Benedikt Koeppel <code@benediktkoeppel.ch>


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


SEE ALSO
--------
- `cdist-type(7) <cdist-type.html>`_


COPYING
-------
Copyright \(C) 2012 Benedikt Koeppel. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
