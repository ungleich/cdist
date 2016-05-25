cdist-type__postgres_database(7)
================================
Create/drop postgres databases

Steven Armstrong <steven-cdist--@--armstrong.cc>


DESCRIPTION
-----------
This cdist type allows you to create or drop postgres databases.


OPTIONAL PARAMETERS
-------------------
state
   either 'present' or 'absent', defaults to 'present'.

owner
   the role owning this database


EXAMPLES
--------

.. code-block:: sh

    __postgres_database mydbname --owner mydbusername


SEE ALSO
--------
- `cdist-type(7) <cdist-type.html>`_
- `cdist-type__postgres_role(7) <cdist-type__postgres_role.html>`_


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
