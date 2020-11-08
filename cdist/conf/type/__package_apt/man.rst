cdist-type__package_apt(7)
==========================

NAME
----
cdist-type__package_apt - Manage packages with apt-get


DESCRIPTION
-----------
apt-get is usually used on Debian and variants (like Ubuntu) to
manage packages. The package will be installed without recommended
or suggested packages. If such packages are required, install them
separatly or use the parameter ``--install-recommends``.

This type will also update package index, if it is older
than one day, to avoid missing package error messages.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
name
    If supplied, use the name and not the object id as the package name.

state
    Either "present" or "absent", defaults to "present"

target-release
    Passed on to apt-get install, see apt-get(8).
    Essentially allows you to retrieve packages from a different release

version
    The version of the package to install. Default is to install the version
    chosen by the local package manager.


BOOLEAN PARAMETERS
------------------
install-recommends
    If the package will be installed, it also installs recommended packages
    with it. It will not install recommended packages if the original package
    is already installed.

    In most cases, it is recommended to install recommended packages separatly
    to control which additional packages will be installed to avoid useless
    installed packages.

purge-if-absent
    If this parameter is given when state is `absent`, the package is
    purged from the system (using `--purge`).


EXAMPLES
--------

.. code-block:: sh

    # Ensure zsh in installed
    __package_apt zsh --state present

    # In case you only want *a* webserver, but don't care which one
    __package_apt webserver --state present --name nginx

    # Remove obsolete package
    __package_apt puppet --state absent


SEE ALSO
--------
:strong:`cdist-type__package`\ (7)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2011-2012 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
