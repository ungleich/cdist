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
entry
   Set ACL entry following ``getfacl`` output syntax.


OPTIONAL PARAMETERS
-------------------
source
   Read ACL entries from stdin or file.
   Ordering of entries is not important.
   When reading from file, comments and empty lines are ignored.

file
   Create/change file with ``__file`` using ``user:group:mode`` pattern.

directory
   Create/change directory with ``__directory`` using ``user:group:mode`` pattern.


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
Parameters ``acl``, ``user``, ``group``, ``mask`` and ``other`` are deprecated and they
will be removed in future versions. Please use ``entry`` parameter instead.


EXAMPLES
--------

.. code-block:: sh

    __acl /srv/project \
        --default \
        --recursive \
        --remove \
        --entry user:alice:rwx \
        --entry user:bob:r-x \
        --entry group:project-group:rwx \
        --entry group:some-other-group:r-x \
        --entry mask::r-x \
        --entry other::r-x

    # give Alice read-only access to subdir,
    # but don't allow her to see parent content.

    __acl /srv/project2 \
        --remove \
        --entry default:group:secret-project:rwx \
        --entry group:secret-project:rwx \
        --entry user:alice:--x

    __acl /srv/project2/subdir \
        --default \
        --remove \
        --entry group:secret-project:rwx \
        --entry user:alice:r-x

    # read acl from stdin
    echo 'user:alice:rwx' \
        | __acl /path/to/directory --source -

    # create/change directory too
    __acl /path/to/directory \
        --default \
        --remove \
        --directory root:root:770 \
        --entry user:nobody:rwx


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2018 Ander Punnar. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
