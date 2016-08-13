cdist-type__package(7)
======================

NAME
----
cdist-type__package - Manage packages


DESCRIPTION
-----------
This cdist type allows you to install or uninstall packages on the target.
It dispatches the actual work to the package system dependent types.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
name
    The name of the package to install. Default is to use the object_id as the
    package name.
version
    The version of the package to install. Default is to install the version
    chosen by the local package manager.
type
    The package type to use. Default is determined based on the $os explorer
    variable.
    e.g.
    * __package_apt for Debian
    * __package_emerge for Gentoo

state
    Either "present" or "absent", defaults to "present"


EXAMPLES
--------

.. code-block:: sh

    # Install the package vim on the target
    __package vim --state present

    # Same but install specific version
    __package vim --state present --version 7.3.50

    # Force use of a specific package type
    __package vim --state present --type __package_apt


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
