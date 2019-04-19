cdist-type__acl(7)
==================

NAME
----
cdist-type__acl - Set ACL entries


DESCRIPTION
-----------
ACL must be defined as 3-symbol combination, using ``r``, ``w``, ``x`` and ``-``.

Fully supported on Linux (tested on Debian and CentOS).

Partial support for FreeBSD, OSX and Solaris.

OpenBSD and NetBSD support is not possible.

See ``setfacl`` and ``acl`` manpages for more details.


OPTIONAL MULTIPLE PARAMETERS
----------------------------
user
   Add user ACL entry.

group
   Add group ACL entry.


OPTIONAL PARAMETERS
-------------------
mask
   Add mask ACL entry.

other
   Add other ACL entry.


BOOLEAN PARAMETERS
------------------
recursive
   Make ``setfacl`` recursive (Linux only), but not ``getfacl`` in explorer.

default
   Add default ACL entries (FreeBSD not supported).

remove
   Remove undefined ACL entries (Solaris not supported).
   ACL entries for ``mask`` and ``other`` can't be removed.


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
        --group some-other-group:r-x \
        --mask r-x \
        --other r-x


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2018 Ander Punnar. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
