cdist-type__package_zypper(7)
=============================

NAME
----
cdist-type__package_zypper - Manage packages with zypper


DESCRIPTION
-----------
Zypper is usually used on the SuSE distribution to manage packages.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
name
    If supplied, use the name and not the object id as the package name.

state
    Either "present" or "absent", defaults to "present"

version
    The version of the package to install. Default is to install the version
    chosen by the local package manager. For a list of available versions,
    have a look at the output of "zypper se -s packagename"

ptype
    Either "package", "patch", "pattern", "product" or "srcpackage", defaults to "package". For a description see man zypper.


EXAMPLES
--------

.. code-block:: sh

    # Ensure zsh is installed
    __package_zypper zsh --state present

    # If you don't want to follow pythonX packages, but always use python
    __package_zypper python --state present --name python2

    # Ensure binutils is installed and the version is forced to be 2.23.1-0.19.2
    __package_zypper binutils --state present --version 2.23.1-0.19.2

    # Remove package
    __package_zypper cfengine --state absent

    # install all packages which belongs to pattern x11
    __package_zypper x11 --ptype pattern --state present


SEE ALSO
--------
:strong:`cdist-type__package`\ (7)


AUTHORS
-------
Daniel Heule <hda--@--sfs.biz>


COPYING
-------
Copyright \(C) 2012 Nico Schottelius.
Copyright \(C) 2013 Daniel Heule.
You can redistribute it and/or modify it under the terms of the
GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.
