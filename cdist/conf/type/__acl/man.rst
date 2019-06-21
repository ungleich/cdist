cdist-type__acl(7)
==================

NAME
----
cdist-type__acl - Set ACL entries


DESCRIPTION
-----------
Fully supported and tested on Linux (ext4 filesystem), partial support for FreeBSD.

See ``setfacl`` and ``acl`` manpages for more details.


REQUIRED MULTIPLE PARAMETERS
----------------------------
acl
   Set ACL entry following ``getfacl`` output syntax.


BOOLEAN PARAMETERS
------------------
default
   Set all ACL entries as default too.
   Only directories can have default ACLs.
   Setting default ACL in FreeBSD is currently not supported.

recursive
   Make ``setfacl`` recursive (Linux only), but not ``getfacl`` in explorer.

remove
   Remove undefined ACL entries.
   ``mask`` and ``other`` entries can't be removed, but only changed.


DEPRECATED PARAMETERS
---------------------
Parameters ``user``, ``group``, ``mask`` and ``other`` are deprecated and they
will be removed in future versions. Please use ``acl`` parameter instead.


EXAMPLES
--------

.. code-block:: sh

    __acl /srv/project \
        --default \
        --recursive \
        --remove \
        --acl user:alice:rwx \
        --acl user:bob:r-x \
        --acl group:project-group:rwx \
        --acl group:some-other-group:r-x \
        --acl mask::r-x \
        --acl other::r-x

    # give Alice read-only access to subdir,
    # but don't allow her to see parent content.

    __acl /srv/project2 \
        --remove \
        --acl default:group:secret-project:rwx \
        --acl group:secret-project:rwx \
        --acl user:alice:--x

    __acl /srv/project2/subdir \
        --default \
        --remove \
        --acl group:secret-project:rwx \
        --acl user:alice:r-x


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2018 Ander Punnar. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
