cdist-type__package_akp(7)
==========================

NAME
----
cdist-type__package_akp - Manage packages with akp


DESCRIPTION
-----------
apk is usually used on Alpine to manage packages.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------
name
   If supplied, use the name and not the object id as the package name.

state
    Either "present" or "absent", defaults to "present"


EXAMPLES
--------

.. code-block:: sh

    # Ensure zsh in installed
    __package_apk zsh --state present

    # Remove package
    __package_apk apache2 --state absent


SEE ALSO
--------
:strong:`cdist-type__package`\ (7)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2019 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
