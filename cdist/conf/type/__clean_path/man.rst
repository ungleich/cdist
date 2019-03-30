cdist-type__clean_path(7)
=========================

NAME
----
cdist-type__clean_path - Remove files and directories which match the pattern.


DESCRIPTION
-----------
Remove files and directories which match the pattern.

Provided path (as __object_id) must be a directory.

Patterns are passed to ``find``'s ``-regex`` - see ``find(1)`` for more details.

Look up of files and directories is non-recursive (``-maxdepth 1``).

Parent directory is excluded (``-mindepth 1``).

This type is not POSIX compatible (sorry, Solaris users).


REQUIRED PARAMETERS
-------------------
pattern
   Pattern of files which are removed from path.


OPTIONAL PARAMETERS
-------------------
exclude
   Pattern of files which are excluded from removal.

onchange
   The code to run if files or directories were removed.


EXAMPLES
--------

.. code-block:: sh

    __clean_path /etc/apache2/conf-enabled \
        --pattern '.+' \
        --exclude '.+\(charset\.conf\|security\.conf\)' \
        --onchange 'service apache2 restart'


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2019 Ander Punnar. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
