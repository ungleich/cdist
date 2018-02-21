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
The filename of the deb package has to follow Debian naming conventions, i.e.
`${binary:Package}_${Version}_${Architecture}.deb` (see `dpkg-query(1)` for
details).


OPTIONAL PARAMETERS
-------------------
state
    `present` or `absent`, defaults to `present`.

REQUIRED PARAMETERS
-------------------
source
    path to the \*.deb package


BOOLEAN PARAMETERS
------------------
purge-if-absent
    If this parameter is given when state is `absent`, the package is
    purged from the system (using `--purge`).


EXPLORER
--------
pkg_state
    Returns the full package name if package is installed, empty otherwise.


MESSAGES
--------
installed
    The deb-file was installed.

removed (--remove)
    The package was removed, keeping config.

removed (--purge)
    The package was removed including config (purged).


EXAMPLES
--------

.. code-block:: sh

    # Install foo and bar packages
    __package_dpkg foo_0.1_all.deb --source /tmp/foo_0.1_all.deb
    __package_dpkg bar_1.4.deb --source $__type/files/bar_1.4.deb

    # uninstall baz:
    __package_dpkg baz_1.4_amd64.deb \
        --source $__type/files/baz_1.4_amd64.deb \
        --state "absent"
    # uninstall baz and also purge config-files:
    __package_dpkg baz_1.4_amd64.deb \
        --source $__type/files/baz_1.4_amd64.deb \
        --purge-if-absent \
        --state "absent"


SEE ALSO
--------
:strong:`cdist-type__package`\ (7), :strong:`dpkg-query`\ (1)


AUTHORS
-------
| Tomas Pospisek <tpo_deb--@--sourcepole.ch>
| Thomas Eckert <tom--@--it-eckert.de>


COPYING
-------
Copyright \(C) 2013 Tomas Pospisek. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
This type is based on __package_apt.
