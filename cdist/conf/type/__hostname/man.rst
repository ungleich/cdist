cdist-type__hostname(7)
=======================

NAME
----
cdist-type__hostname - Set the hostname


DESCRIPTION
-----------
Set's the hostname on various operating systems.


REQUIRED PARAMETERS
-------------------
None.

OPTIONAL PARAMETERS
-------------------
name
   The hostname to set. Defaults to the first segment of __target_host 
   (${__target_host%%.*})


MESSAGES
--------
changed
    Changed the hostname

EXAMPLES
--------

.. code-block:: sh

    # take hostname from __target_host
    __hostname

    # set hostname explicitly
    __hostname --name some-static-hostname


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2012 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
