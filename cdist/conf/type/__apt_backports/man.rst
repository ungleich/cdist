cdist-type__debian_backports(7)
===============================

NAME
----
cdist-type__apt_backports - Install backports


DESCRIPTION
-----------
This singleton type installs backports for the current OS release.
It aborts if backports are not supported for the specified OS or
no version codename could be fetched (like Debian unstable).

The package index will be automatically updated if required.

It supports backports from following OSes:

- Debian
- Devuan
- Ubuntu


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
    The mirror to fetch the backports from. Will defaults to the generic
    mirror of the current OS.

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
   __apt_backports
   __apt_backports --state absent
   __apt_backports --state present --mirror "http://ftp.de.debian.org/debian/"

   # install a backports package
   # currently for the buster release backports
   require="__apt_backports" __package_apt wireguard \
        --target-release buster-backports


ABORTS
------
Aborts if the detected os is not Debian.

Aborts if no distribuition codename could be detected. This is common for the
unstable distribution, but there is no backports repository for it already.


CAVEATS
-------
For Ubuntu, it setup all componenents for the backports repository: ``main``,
``restricted``, ``universe`` and ``multiverse``. The user may not want to
install proprietary packages, which will only be installed if the user
explicitly uses the backports target-release. The user may change this behavior
to install backports packages without the need of explicitly select it.


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
