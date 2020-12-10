cdist-type__debian_backports(7)
===============================

NAME
----
cdist-type__debian_backports - Install backports for Debain systems


DESCRIPTION
-----------
This singleton type installs backports for the current Debian version.
It aborts if backports are not supported for the specified os or no
version codename could be fetched (like Debian unstable).


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
state
    Represents the state of the backports repository. ``present`` or
    ``absent``, defaults to ``present``.

    Will be directly passed to :strong:`cdist-type__apt_source`\ (7).

mirror
    The mirror to fetch the backports from. Will defaults to the Debian default
    `<http://deb.debian.org/debian/>`_.

    Will be directly passed to :strong:`cdist-type__apt_source`\ (7).


BOOLEAN PARAMETERS
------------------
None.


MESSAGES
--------
None.


EXAMPLES
--------

.. code-block:: sh

   # setup the backports
   __debian_backports
   __debian_backports --state absent
   __debian_backports --state present --mirror "http://ftp.de.debian.org/debian/"

   # update
   require="__debian_backports" __apt_update_index

   # install a backports package
   # currently for the buster release backports
   require="__apt_update_index" __package_apt wireguard \
        --target-release buster-backports


ABORTS
------
Aborts if the detected os is not Debian.

Aborts if no distribuition codename could be detected. This is common for the
unstable distribution, but there is no backports repository for it already.


SEE ALSO
--------
`Official Debian Backports site <https://backports.debian.org/>`_

:strong:`cdist-type__apt_source`\ (7)


AUTHORS
-------
Matthias Stecher <matthiasstecher at gmx.de>


COPYING
-------
Copyright \(C) 2020 Matthias Stecher. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
