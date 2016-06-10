cdist-type__issue(7)
====================
Manage issue

Nico Schottelius <nico-cdist--@--schottelius.org>


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


SEE ALSO
--------
- `cdist-type(7) <cdist-type.html>`_


COPYING
-------
Copyright \(C) 2011 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
