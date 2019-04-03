cdist-type__check_messages(7)
=============================

NAME
----
cdist-type__check_messages - Check messages for pattern and execute command on match.


DESCRIPTION
-----------
Check messages for pattern and execute command on match.

This type is useful if you chain together multiple related types using
dependencies and want to restart service if at least one type changes
something.

For more information about messages see `cdist messaging <cdist-messaging.html>`_.

For more information about dependencies and execution order see
`cdist manifest <cdist-manifest.html#dependencies>`_ documentation.


REQUIRED PARAMETERS
-------------------
pattern
   Extended regular expression pattern for search (passed to ``grep -E``).

execute
   Command to execute on pattern match.


EXAMPLES
--------

.. code-block:: sh

    __check_messages munin \
        --pattern '^__(file|link|line)/etc/munin/' \
        --execute 'service munin-node restart'


AUTHORS
-------
Ander Punnar <ander-at-kvlt-dot-ee>


COPYING
-------
Copyright \(C) 2019 Ander Punnar. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
