cdist-type__dpkg_architecture(7)
================================

NAME
----
cdist-type__dpkg_architecture - Handles foreign architectures on debian-like
systems managed by `dpkg`


DESCRIPTION
-----------
This type handles foreign architectures on systems managed by
:strong:`dpkg`\ (1). The object id is the name of the architecture accepted by
`dpkg`, which should be added or removed.

If the architecture is not setup on the system, it adds a new architecture as a
new foreign architecture in `dpkg`. Then, it updates the apt package index to
make packages from the new architecture available.

If the architecture should be removed, it will remove it if it is not the base
architecture on where the system was installed on. Before it, it will purge
every package based on the "to be removed" architecture via `apt` to be able to
remove the selected architecture.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
state
    ``present`` or ``absent``. Defaults to ``present``.


MESSAGES
--------
added
   Added the specified architecture

removed
   Removed the specified architecture


ABORTS
------
Aborts in the following cases:

If :strong:`dpkg`\ (1) is not available. It will abort with a proper error
message.

If the architecture is the same as the base architecture the system is build
upon it (returned by ``dpkg --print-architecture``) and it should be removed.

It will fail if it can not execute :strong:`apt`\ (8). It is assumed that it is
already installed.


EXAMPLES
--------

.. code-block:: sh

  # add i386 (32 bit) architecture
  __dpkg_architecture i386

  # remove it again :)
  __dpkg_architecture i386 --state absent


SEE ALSO
--------
`Multiarch on Debian systems <https://wiki.debian.org/Multiarch>`_

`How to setup multiarch on Debian <https://wiki.debian.org/Multiarch/HOWTO>`_

:strong:`dpkg`\ (1)
:strong:`cdist-type__package_dpkg`\ (7)
:strong:`cdist-type__package_apt`\ (7)

Useful commands:

.. code-block:: sh

   # base architecture installed on this system
   dpkg --print-architecture

   # extra architectures added
   dpkg --print-foreign-architectures


AUTHORS
-------
Matthias Stecher <matthiasstecher at gmx.de>


COPYING
-------
Copyright \(C) 2020 Matthias Stecher. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
ublished by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
