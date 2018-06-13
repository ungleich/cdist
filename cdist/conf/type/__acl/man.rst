cdist-type__acl(7)
==================

NAME
----
cdist-type__acl - Basic wrapper around `setfacl`


DESCRIPTION
-----------
ACL must be defined as 3-symbol combination, using `r`, `w`, `x` and `-`.

See setfacl(1) and acl(5) for more details.


OPTIONAL MULTIPLE PARAMETERS
----------------------------
user
   Add user ACL entry.

group
   Add group ACL entry.


BOOLEAN PARAMETERS
------------------
recursive
   Operate recursively (Linux only).

default
   Add default ACL entries.

remove
   Remove undefined ACL entries (Solaris not supported).


EXAMPLES
--------

.. code-block:: sh

    __acl /srv/project \
        --recursive \
        --default \
        --remove \
        --user alice:rwx \
        --user bob:r-x \
        --group project-group:rwx \
        --group some-other-group:r-x


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2018 Ander Punnar. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
