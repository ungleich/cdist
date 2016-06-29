cdist-type__postgres_database(7)
================================

NAME
----
cdist-type__postgres_database - Create/drop postgres databases


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
`cdist-type__postgres_role(7) <cdist-type__postgres_role.html>`_

Full documentation at: <:cdist_docs:`index`>,
especially cdist type chapter: <:cdist_docs:`cdist-type`>.


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
