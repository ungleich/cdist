cdist-type__package_dpkg(7)
===========================

NAME
----
cdist-type__package_dpkg - Manage packages with dpkg


DESCRIPTION
-----------
This type is used on Debian and variants (like Ubuntu) to
install packages that are provided locally as \*.deb files.

The object given to this type must be the name of the deb package.


REQUIRED PARAMETERS
-------------------
source
    path to the \*.deb package

EXAMPLES
--------

.. code-block:: sh

    # Install foo and bar packages
    __package_dpkg --source /tmp/foo_0.1_all.deb foo_0.1_all.deb
    __package_dpkg --source $__type/files/bar_1.4.deb bar_1.4.deb


SEE ALSO
--------
:strong:`cdist-type__package`\ (7)

AUTHORS
-------
Tomas Pospisek <tpo_deb--@--sourcepole.ch>

COPYING
-------
Copyright \(C) 2013 Tomas Pospisek. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
This type is based on __package_apt.
