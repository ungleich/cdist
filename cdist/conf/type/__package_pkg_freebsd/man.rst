cdist-type__package_pkg_freebsd(7)
==================================

NAME
----
cdist-type__package_pkg_freebsd - Manage FreeBSD packages 


DESCRIPTION
-----------
This type is usually used on FreeBSD to manage packages.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
name
    If supplied, use the name and not the object id as the package name.

flavor
    If supplied, use to avoid ambiguity.

version
    If supplied, use to install a specific version of the package named.

pkgsite
    If supplied, use to install from a specific package repository.

state
    Either "present" or "absent", defaults to "present"


EXAMPLES
--------

.. code-block:: sh

    # Ensure zsh is installed
    __package_pkg_freebsd zsh --state present

    # Ensure vim is installed, use flavor no_x11
    __package_pkg_freebsd vim --state present --flavor no_x11

    # If you don't want to follow pythonX packages, but always use python
    __package_pkg_freebsd python --state present --name python2

    # Remove obsolete package
    __package_pkg_freebsd puppet --state absent


SEE ALSO
--------
:strong:`cdist-type__package`\ (7)


AUTHORS
-------
Jake Guffey <jake.guffey--@--eprotex.com>


COPYING
-------
Copyright \(C) 2012 Jake Guffey. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
