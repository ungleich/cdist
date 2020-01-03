cdist-type__mysql_user(7)
=========================

NAME
----
cdist-type__mysql_user - Manage a MySQL user


DESCRIPTION
-----------

Create MySQL user or change password for the user.


OPTIONAL PARAMETERS
-------------------
name
   Name of user. Defaults to object id.

host
   Host of user. Defaults to localhost.

password
   Password of user.

state
   Defaults to present.


EXAMPLES
--------

.. code-block:: sh

    __mysql_user user --password secret


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2020 Ander Punnar. You can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.
