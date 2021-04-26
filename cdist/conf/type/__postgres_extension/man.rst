cdist-type__postgres_extension(7)
=================================

NAME
----
cdist-type__postgres_extension - Manage PostgreSQL extensions


DESCRIPTION
-----------
This cdist type allows you to manage PostgreSQL extensions.

The ``__object_id`` to pass to ``__postgres_extension`` is of the form
``dbname:extension``, e.g.:

.. code-block:: sh

    rails_test:unaccent


**CAUTION!** Be careful when installing extensions from (untrusted) third-party
sources:

   | Installing an extension as superuser requires trusting that the extension's
     author wrote the extension installation script in a secure fashion. It is
     not terribly difficult for a malicious user to create trojan-horse objects
     that will compromise later execution of a carelessly-written extension
     script, allowing that user to acquire superuser privileges.
   | – `<https://www.postgresql.org/docs/13/sql-createextension.html#id-1.9.3.64.7>`_


OPTIONAL PARAMETERS
-------------------
state
    either ``present`` or ``absent``, defaults to ``present``.


EXAMPLES
--------

.. code-block:: sh

   # Install extension unaccent into database rails_test
   __postgres_extension rails_test:unaccent

   # Drop extension unaccent from database fails_test
   __postgres_extension rails_test:unaccent --state absent


SEE ALSO
--------
- :strong:`cdist-type__postgres_database`\ (7)
- PostgreSQL "CREATE EXTENSION" documentation at:
  `<http://www.postgresql.org/docs/current/static/sql-createextension.html>`_.


AUTHORS
-------
| Tomas Pospisek <tpo_deb--@--sourcepole.ch>
| Dennis Camera <dennis.camera--@--ssrq-sds-fds.ch>


COPYING
-------
Copyright \(C) 2014 Tomas Pospisek, 2021 Dennis Camera.
You can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.
