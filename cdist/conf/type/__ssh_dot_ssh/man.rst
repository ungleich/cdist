cdist-type__ssh_dot_ssh(7)
==========================
Manage .ssh directory

Nico Schottelius <nico-cdist--@--schottelius.org>


NAME
----


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
- `cdist-type(7) <cdist-type.html>`_
- `cdist-type__ssh_authorized_keys(7) <cdist-type__ssh_authorized_keys.html>`_


COPYING
-------
Copyright \(C) 2014 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
