cdist-type__directory(7)
========================

NAME
----
cdist-type__directory - Manage a directory


DESCRIPTION
-----------
This cdist type allows you to create or remove directories on the target.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
state
   'present' or 'absent', defaults to 'present'

group
   Group to chgrp to.

mode
   Unix permissions, suitable for chmod.

owner
   User to chown to.


BOOLEAN PARAMETERS
------------------
parents
   Whether to create parents as well (mkdir -p behaviour).
   Warning: all intermediate directory permissions default
   to whatever mkdir -p does. 

   Usually this means root:root, 0700.

recursive
   If supplied the chgrp and chown call will run recursively.
   This does *not* influence the behaviour of chmod.

MESSAGES
--------
chgrp <group>
    Changed group membership
chown <owner>
    Changed owner
chmod <mode>
    Changed mode
create
    Empty directory was created
remove
    Directory exists, but state is absent, directory will be removed by generated code.
remove non directory
    Something other than a directory with the same name exists and was removed prior to create.


EXAMPLES
--------

.. code-block:: sh

    # A silly example
    __directory /tmp/foobar

    # Remove a directory
    __directory /tmp/foobar --state absent

    # Ensure /etc exists correctly
    __directory /etc --owner root --group root --mode 0755

    # Create nfs service directory, including parents
    __directory /home/services/nfs --parents

    # Change permissions recursively
    __directory /home/services --recursive --owner root --group root

    # Setup a temp directory
    __directory /local --mode 1777

    # Take it all
    __directory /home/services/kvm --recursive --parents \
        --owner root --group root --mode 0755 --state present


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2011 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
