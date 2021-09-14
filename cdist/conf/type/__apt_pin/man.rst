cdist-type__apt_pin(7)
======================

NAME
----
cdist-type__apt_pin - Manage apt pinning rules


DESCRIPTION
-----------
Adds/removes/edits rules to pin some packages to a specific distribution. Useful if using multiple debian repositories at the same time. (Useful, if one wants to use a few specific packages from backports or perhaps Debain testing... or even sid.)


REQUIRED PARAMETERS
-------------------
distribution
   Specifies what distribution the package should be pinned to. Accepts both codenames (buster/bullseye/sid) and suite names (stable/testing/...).


OPTIONAL PARAMETERS
-------------------
package
   Package name, glob or regular expression to match (multiple) packages. If not specified `__object_id` is used.

priority
   The priority value to assign to matching packages. Deafults to 500. (To match the default target distro's priority)

state
   Will be passed to underlying `__file` type; see there for valid values and defaults.



BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

   # Add the bullseye repo to buster, but do not install any packages by default,
   # only if explicitely asked for (-1 means "never" for apt)
    __apt_pin bullseye-default \
       --package "*" \
       --distribution bullseye \
       --priority -1

    require="__apt_pin/bullseye-default" __apt_source bullseye \
       --uri http://deb.debian.org/debian/ \
       --distribution bullseye \
       --component main

    __apt_pin foo --package "foo foo-*" --distribution bullseye

    __foo # Assuming, this installs the `foo` package internally

    __package foo-plugin-extras # Assuming we also need some extra stuff


SEE ALSO
--------
:strong:`apt_preferences`\ (5)
:strong:`cdist-type__apt_source`\ (7)
:strong:`cdist-type__apt_backports`\ (7)
:strong:`cdist-type__file`\ (7)

AUTHORS
-------
Daniel Fancsali <fancsali@gmail.com>


COPYING
-------
Copyright \(C) 2021 Daniel Fancsali. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
