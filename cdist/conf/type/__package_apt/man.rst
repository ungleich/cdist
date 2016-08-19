cdist-type__package_apt(7)
==========================

NAME
----
cdist-type__package_apt - Manage packages with apt-get


DESCRIPTION
-----------
apt-get is usually used on Debian and variants (like Ubuntu) to
manage packages.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
name
   If supplied, use the name and not the object id as the package name.

state
    Either "present" or "absent", defaults to "present"

target-release
    Passed on to apt-get install, see apt-get(8).
    Essentially allows you to retrieve packages from a different release

EXAMPLES
--------

.. code-block:: sh

    # Ensure zsh in installed
    __package_apt zsh --state present

    # In case you only want *a* webserver, but don't care which one
    __package_apt webserver --state present --name nginx

    # Remove obsolete package
    __package_apt puppet --state absent


SEE ALSO
--------
:strong:`cdist-type__package`\ (7)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2011-2012 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
