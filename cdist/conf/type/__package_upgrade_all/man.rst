cdist-type__package_upgrade_all(7)
==================================

NAME
----
cdist-type__package_upgrade_all - Upgrade all the installed packages


DESCRIPTION
-----------
This cdist type allows you to upgrade all the installed packages on the
target. It will automatically use the appropriate package manager.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
type
    The package manager to use. Default is determined based on the $os
    explorer variable.
    e.g.
    * apt for Debian
    * yum for Red Hat
    * pacman for Arch Linux


BOOLEAN PARAMETERS
------------------
apt-dist-upgrade
    Do dist-upgrade instead of upgrade.

apt-clean
    Clean out the local repository of retrieved package files.


EXAMPLES
--------

.. code-block:: sh

    # Upgrade all the installed packages on the target
    __package_upgrade_all

    # Force use of a specific package manager
    __package_upgrade_all --type apt


AUTHORS
-------
Ricardo Catalinas Jiménez <jimenezrick--@--gmail.com>

COPYING
-------

Copyright \(C) 2014 Ricardo Catalinas Jiménez. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
