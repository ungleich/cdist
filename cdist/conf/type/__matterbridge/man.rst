cdist-type__matterbridge(7)
===========================

NAME
----
cdist-type__matterbridge - Install matterbridge from upstream binary


DESCRIPTION
-----------
This singleton type install a matterbridge service from binary.

REQUIRED PARAMETERS
-------------------
version
  Release (git tag) to fetch from the project github's page.

config
  Matterbridge configuration (TOML).

OPTIONAL PARAMETERS
-------------------
None.


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

    __matterbridge --version 1.16.3 --config - << EOF
    [...]
EOF


SEE ALSO
--------
- `Matterbridge github repository <https://github.com/42wim/matterbridge>`_


AUTHORS
-------
Timothée Floure <timothee.floure@ungleich.ch>


COPYING
-------
Copyright \(C) 2020 Timothée Floure. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
