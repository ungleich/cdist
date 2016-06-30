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
Copyright \(C) 2012 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
