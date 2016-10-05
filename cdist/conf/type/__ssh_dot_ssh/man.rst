cdist-type__ssh_dot_ssh(7)
==========================

NAME
----
cdist-type__ssh_dot_ssh - Manage .ssh directory


DESCRIPTION
-----------
Adds or removes .ssh directory to a user home.

This type is being used by __ssh_authorized_keys.


OPTIONAL PARAMETERS
-------------------
state
   if the directory should be 'present' or 'absent', defaults to 'present'.


EXAMPLES
--------

.. code-block:: sh

    # Ensure root has ~/.ssh with the right permissions
    __ssh_dot_ssh root

    # Nico does not need ~/.ssh anymore
    __ssh_dot_ssh nico --state absent


SEE ALSO
--------
:strong:`cdist-type__ssh_authorized_keys`\ (7)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2014 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
