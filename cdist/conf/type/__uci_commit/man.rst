cdist-type__uci_commit(7)
=========================

NAME
----
cdist-type__uci_commit - Commit UCI transactions


DESCRIPTION
-----------
This type executes the ``uci commit`` command on the target with the commands
queued in a transaction.
It is usually not required to use this type. Use the ``--transaction`` parameter
of :strong:`cdist-type__uci`\ (7) and :strong:`cdist-type__uci_section`\ (7)
instead.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
None.


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

    # Commit the default transaction
    __uci_commit default

    # Commit another transaction
    __uci_commit my_transaction


SEE ALSO
--------
:strong:`cdist-type__uci`\ (7), :strong:`cdist-type__uci_section`\ (7)


AUTHORS
-------
Dennis Camera <dennis.camera@ssrq-sds-fds.ch>


COPYING
-------
Copyright \(C) 2020 Dennis Camera. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
