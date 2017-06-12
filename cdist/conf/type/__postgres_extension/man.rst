cdist-type__postgres_extension(7)
=================================

NAME
----
cdist-type__postgres_extension - manage postgres extensions


DESCRIPTION
-----------
This cdist type allows you to create or drop postgres extensions.

The object you need to pass to __postgres_extension consists of
the database name and the extension name joined by a colon in the
following form:

.. code-block:: sh

    dbname:extension

f.ex.

.. code-block:: sh

    rails_test:unaccent


OPTIONAL PARAMETERS
-------------------
state
    either "present" or "absent", defaults to "present"


EXAMPLES
--------

.. code-block:: sh

    __postgres_extension           rails_test:unaccent
    __postgres_extension --present rails_test:unaccent
    __postgres_extension --absent  rails_test:unaccent


SEE ALSO
--------
:strong:`cdist-type__postgre_database`\ (7)

Postgres "Create Extension" documentation at: <http://www.postgresql.org/docs/current/static/sql-createextension.html>.

AUTHOR
-------
Tomas Pospisek <tpo_deb--@--sourcepole.ch>

COPYING
-------
Copyright \(C) 2014 Tomas Pospisek. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
