cdist-type__motd(7)
===================

NAME
----
cdist-type__motd - Manage message of the day


DESCRIPTION
-----------
This cdist type allows you to easily setup /etc/motd.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
source
   If supplied, copy this file from the host running cdist to the target.
   If not supplied, a default message will be placed onto the target.


EXAMPLES
--------

.. code-block:: sh

    # Use cdist defaults
    __motd

    # Supply source file from a different type
    __motd --source "$__type/files/my-motd"


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2011 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
