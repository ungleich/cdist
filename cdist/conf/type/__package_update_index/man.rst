cdist-type__package_update_index(7)
===================================

NAME
----
cdist-type__update_index - Update the package index


DESCRIPTION
-----------
This cdist type allows you to update the package index on the target.
It will automatically use the appropriate package manager.


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

maxage
    Available for package manager apt and pacman, max time in seconds since
    last update. Repo update is skipped if maxage is not reached yet.

MESSAGES
--------
apt-cache updated (age was: currage)
        apt-cache was updated (run of `apt-get update`). `currage` is the time
        in seconds since the previous run.


EXAMPLES
--------

.. code-block:: sh

    # Update the package index on the target
    __package_update_index

    # Force use of a specific package manager
    __package_update_index --type apt

    # Only update every hour:
    __package_update_index --maxage 3600 --type apt

    # same as above (on apt-type systems):
    __package_update_index --maxage 3600

AUTHORS
-------
| Ricardo Catalinas Jiménez <jimenezrick--@--gmail.com>
| Thomas Eckert <tom--@--it-eckert.de>
| Stu Zhao <z12y12l12--@--gmail.com>


COPYING
-------

Copyright \(C) 2014 Ricardo Catalinas Jiménez. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
