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
Copyright \(C) 2012 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
