cdist-type__apt_pin(7)
======================

NAME
----
cdist-type__apt_pin - TODO


DESCRIPTION
-----------
This space intentionally left blank.


REQUIRED PARAMETERS
-------------------
distribution
   Specifies what distribution the package should be pinned to. Accepts both codenames (buster/bullseye/sid) and suite names (stable/testing/...).


OPTIONAL PARAMETERS
-------------------
package
   Package name or glob/RE expression to match multiple packages. If not specified `__object_id` is used.

priority
   The priority value to assign to matching packages. Deafults to 500. (To match the default target distro's priority)

state
   Will be passed to underlying `__file` type; see there for valid values and defaults.

None.


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

   # Add the bullseye repo to buster, but do not install any pacakges by default
   # only if explicitely asked for
    __apt_pin bullseye-default \
       --package "*" \
       --distribution bullseye \
       --priority -1

    require="__apt_pin/bullseye-default" __apt_source bullseye \
       --uri http://deb.debian.org/debian/ \
       --distribution bullseye \
       --component main
       # TODO
       __apt_pin

    __apt_pin foo --package "foo foo-*" --distribution bullseye

    __foo # Installs the `foo` package internally

    __package foo-plugin-extras


SEE ALSO
--------
:strong:`apt_preferences`\ (7)
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
