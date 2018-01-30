cdist-type__apt_update_index(7)
===============================

NAME
----
cdist-type__apt_update_index - Update apt's package index


DESCRIPTION
-----------
This cdist type runs apt-get update whenever any apt sources have changed.
Should not be called directly (is used by `__apt_source` and `__apt_ppa`).


REQUIRED PARAMETERS
-------------------
None.

OPTIONAL PARAMETERS
-------------------
None.


EXAMPLES
--------

.. code-block:: sh

    __apt_update_index "$__object_id"


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
