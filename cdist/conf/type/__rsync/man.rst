cdist-type__rsync(7)
====================

NAME
----
cdist-type__rsync - Mirror directories using ``rsync``


DESCRIPTION
-----------
The purpose of this type is to bring power of ``rsync`` into ``cdist``.


REQUIRED PARAMETERS
-------------------
source
   Source directory in local machine.
   If source is directory, slash (``/``) will be added to source and destination paths.


OPTIONAL PARAMETERS
-------------------
destination
   Destination directory. Defaults to ``$__object_id``.

owner
   Will be passed to ``rsync`` as ``--chown=OWNER``.
   Read ``rsync(1)`` for more details.

group
   Will be passed to ``rsync`` as ``--chown=:GROUP``.
   Read ``rsync(1)`` for more details.

mode
   Will be passed to ``rsync`` as ``--chmod=MODE``.
   Read ``rsync(1)`` for more details.

options
   Defaults to ``--recursive --links --perms --times``.
   Due to `bug in Python's argparse<https://bugs.python.org/issue9334>`_, value must be prefixed with ``\``.

remote-user
   Defaults to ``root``.


OPTIONAL MULTIPLE PARAMETERS
----------------------------
option
   Pass additional options to ``rsync``.
   See ``rsync(1)`` for all possible options.
   Due to `bug in Python's argparse<https://bugs.python.org/issue9334>`_, value must be prefixed with ``\``.


EXAMPLES
--------
.. code-block:: sh

    __rsync /var/www/example.com \
        --owner root \
        --group www-data \
        --mode 'D750,F640' \
        --source "$__files/example.com/www"


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2021 Ander Punnar. You can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.
