cdist-type__package_yum(7)
==========================

NAME
----
cdist-type__package_yum - Manage packages with yum


DESCRIPTION
-----------
Yum is usually used on the Fedora distribution to manage packages.
If you specify an unknown package, yum will display the
slightly confusing error message "Error: Nothing to do".


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
name
    If supplied, use the name and not the object id as the package name.

state
    Either "present" or "absent", defaults to "present"
url
    URL to use for the package


EXAMPLES
--------

.. code-block:: sh

    # Ensure zsh in installed
    __package_yum zsh --state present

    # If you don't want to follow pythonX packages, but always use python
    __package_yum python --state present --name python2

    # Remove obsolete package
    __package_yum puppet --state absent

    __package epel-release-6-8 \
        --url http://mirror.switch.ch/ftp/mirror/epel/6/i386/epel-release-6-8.noarch.rpm


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
