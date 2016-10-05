cdist-type__package_pkgng_freebsd(7)
====================================

NAME
----
cdist-type__package_pkgng_freebsd - Manage FreeBSD packages with pkg-ng


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

repo
    If supplied, use to install the package named from a particular repo.

state
    Either "present" or "absent", defaults to "present"


BOOLEAN PARAMETERS
------------------
upgrade
    If supplied, allow upgrading to the latest version of a package.


CAVEATS
-------
This type requires that repository definitions already exist in /etc/pkg/\*.conf.
Ensure that they exist prior to use of this type with __file.

pkg-ng can't upgrade a package to a specific version. If this type needs to
upgrade a package, it can only ugprade to the latest available version. If the
"upgrade" parameter is not given and an upgrade needs to occur, an error will result.


MESSAGES
--------
install
   The package was installed
remove
   The package was removed
upgrade
   The package was upgraded
exist
   The package was already present and thus not installed


EXAMPLES
--------

.. code-block:: sh

    # Ensure zsh is installed
    __package_pkgng_freebsd zsh --state present

    # Ensure vim is installed, use flavor no_x11
    __package_pkgng_freebsd vim --state present --flavor no_x11

    # If you don't want to follow pythonX packages, but always use python
    __package_pkgng_freebsd python --state present --name python2

    # Install a package from a particular repository when multiples exist
    __package_pkgng_freebsd bash --state present --repo myrepo

    # Remove obsolete package
    __package_pkgng_freebsd puppet --state absent


SEE ALSO
--------
:strong:`cdist-type__package`\ (7)


AUTHORS
-------
Jake Guffey <jake.guffey--@--eprotex.com>


COPYING
-------
Copyright \(C) 2014 Jake Guffey. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
