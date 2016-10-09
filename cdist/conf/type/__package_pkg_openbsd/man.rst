cdist-type__package_pkg(7)
==========================

NAME
----
cdist-type__package_pkg - Manage OpenBSD packages


DESCRIPTION
-----------
This type is usually used on OpenBSD to manage packages.


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
    If supplied, use to avoid ambiguity.

state
    Either "present" or "absent", defaults to "present"

pkg_path
    Manually specify a PKG_PATH to add packages from.

EXAMPLES
--------

.. code-block:: sh

    # Ensure zsh is installed
    __package_pkg_openbsd zsh --state present

    # Ensure vim is installed, use flavor no_x11
    __package_pkg_openbsd vim --state present --flavor no_x11

    # If you don't want to follow pythonX packages, but always use python
    __package_pkg_openbsd python --state present --name python2

    # Remove obsolete package
    __package_pkg_openbsd puppet --state absent

    # Add a package using a particular mirror
    __package_pkg_openbsd bash \
      --pkg_path http://openbsd.mirrorcatalogs.com/snapshots/packages/amd64


SEE ALSO
--------
:strong:`cdist-type__package`\ (7)


AUTHORS
-------
Andi Brönnimann <andi-cdist--@--v-net.ch>


COPYING
-------
Copyright \(C) 2011 Andi Brönnimann. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
