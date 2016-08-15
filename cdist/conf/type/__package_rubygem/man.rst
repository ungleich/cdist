cdist-type__package_rubygem(7)
==============================

NAME
----
cdist-type__package_rubygem - Manage rubygem packages


DESCRIPTION
-----------
Rubygems is the default package management system for the Ruby programming language.


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

    # Ensure sinatra is installed
    __package_rubygem sinatra --state present

    # Remove package
    __package_rubygem rails --state absent


SEE ALSO
--------
:strong:`cdist-type__package`\ (7)


AUTHORS
-------
Chase Allen James <nx-cdist@nu-ex.com>


COPYING
-------

Copyright \(C) 2011 Chase Allen James. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
