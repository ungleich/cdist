cdist-type__motd(7)
===================
Manage message of the day

Nico Schottelius <nico-cdist--@--schottelius.org>


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


SEE ALSO
--------
- `cdist-type(7) <cdist-type.html>`_


COPYING
-------
Copyright \(C) 2011 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
