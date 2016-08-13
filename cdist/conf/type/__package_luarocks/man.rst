cdist-type__package_luarocks(7)
===============================

NAME
----
cdist-type__package_luarocks - Manage luarocks packages


DESCRIPTION
-----------
LuaRocks is a deployment and management system for Lua modules.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
name
    If supplied, use the name and not the object id as the package name.

state
    Either "present" or "absent", defaults to "present"


EXAMPLES
--------

.. code-block:: sh

    # Ensure luasocket is installed
    __package_luarocks luasocket --state present

    # Remove package
    __package_luarocks luasocket --state absent


SEE ALSO
--------
:strong:`cdist-type__package`\ (7)


AUTHORS
-------
Christian G. Warden <cwarden@xerus.org>


COPYING
-------
Copyright \(C) 2012 SwellPath, Inc. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
