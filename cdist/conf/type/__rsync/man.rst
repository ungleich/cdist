cdist-type__rsync(7)
====================

NAME
----
cdist-type__rsync - Mirror directories using rsync


DESCRIPTION
-----------
WARNING: This type is of BETA quality:

- it has not been tested widely
- interfaces *may* change
- if there is a better approach to solve the problem -> the type may even vanish

If you are fine with these constraints, please read on.


This cdist type allows you to mirror local directories to the
target host using rsync. Rsync will be installed in the manifest of the type.
If group or owner are giveng, a recursive chown will be executed on the 
target host.

A slash will be appended to the source directory so that only the contents
of the directory are taken and not the directory name itself.


REQUIRED PARAMETERS
-------------------
source
    Where to take files from


OPTIONAL PARAMETERS
-------------------
group
   Group to chgrp to.

owner
   User to chown to.

destination
    Use this as the base destination instead of the object id

remote-user
    Use this user instead of the default "root" for rsync operations.


OPTIONAL MULTIPLE PARAMETERS
----------------------------
rsync-opts
    Use this option to give rsync options with.
    See rsync(1) for available options.
    Only "--" options are supported.
    Write the options without the beginning "--"
    Can be specified multiple times.


MESSAGES
--------
NONE


EXAMPLES
--------

.. code-block:: sh

    # You can use any source directory
    __rsync /tmp/testdir \
        --source /etc

    # Use source from type
    __rsync /etc \
        --source "$__type/files/package"

    # Allow multiple __rsync objects to write to the same dir
    __rsync mystuff \
        --destination /usr/local/bin \
        --source "$__type/files/package"

    __rsync otherstuff \
        --destination /usr/local/bin \
        --source "$__type/files/package2"

    # Use rsync option --exclude
    __rsync /tmp/testdir \
        --source /etc \
        --rsync-opts exclude=sshd_conf

    # Use rsync with multiple options --exclude --dry-run
    __rsync /tmp/testing \
        --source /home/tester \
        --rsync-opts exclude=id_rsa \
        --rsync-opts dry-run


SEE ALSO
--------
:strong:`rsync`\ (1)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2015 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
