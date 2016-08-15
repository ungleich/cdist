cdist-type__user_groups(7)
==========================

NAME
----
cdist-type__user_groups - Manage user groups


DESCRIPTION
-----------
Adds or removes a user from one or more groups.


REQUIRED PARAMETERS
-------------------
group
   the group to which this user should be added or removed.
   Can be specified multiple times.


OPTIONAL PARAMETERS
-------------------
user
   the name of the user. Defaults to object_id

state
   absent or present. Defaults to present.


EXAMPLES
--------

.. code-block:: sh

    __user_groups nginx --group webuser1 --group webuser2

    # remove user nginx from groups webuser2
    __user_groups nginx-webuser2 --user nginx \
       --group webuser2 --state absent


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2012 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
