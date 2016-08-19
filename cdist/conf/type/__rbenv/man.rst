cdist-type__rbenv(7)
====================

NAME
----
cdist-type__rbenv - Manage rbenv installation


DESCRIPTION
-----------
This cdist type allows you to manage rbenv installations.
It also installs ruby-build.


OPTIONAL PARAMETERS
-------------------
state
    Either "present" or "absent", defaults to "present"

owner
    Which user should own the rbenv installation, defaults to root


EXAMPLES
--------

.. code-block:: sh

    # Install rbenv including ruby-build for nico
    __rbenv /home/nico

    # Install rbenv including ruby-build for nico
    __rbenv /home/nico --owner nico

    # Bastian does not need rbenv anymore, he began to code C99
    __rbenv /home/bastian --state absent


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2012-2014 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
