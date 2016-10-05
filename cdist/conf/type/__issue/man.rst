cdist-type__issue(7)
====================

NAME
----
cdist-type__issue - Manage issue


DESCRIPTION
-----------
This cdist type allows you to easily setup /etc/issue.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
source
   If supplied, use this file as /etc/issue instead of default.



EXAMPLES
--------

.. code-block:: sh

    __issue

    # When called from another type
    __issue --source "$__type/files/myfancyissue"


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2011 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
