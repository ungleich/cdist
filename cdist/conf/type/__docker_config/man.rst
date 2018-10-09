cdist-type__docker_config(7)
============================

NAME
----

cdist-type__docker_config - Manage Docker configs

DESCRIPTION
-----------

This type manages Docker configs.

OPTIONAL PARAMETERS
-------------------

source
    Path to the source file. If it is '-' (dash), read standard input.

state
    'present' or 'absent', defaults to 'present' where:

    present
        if the config does not exist, it is created
    absent
        the config is removed

CAVEATS
-------

Since Docker configs cannot be updated once created, this type tries removing
and recreating the config if it changes. If the config is used by a service at
the time of removing, then this type will fail.

EXAMPLES
--------

.. code-block:: sh

    # Creates "foo" config from "bar" source file
    __docker_config foo --source bar


AUTHORS
-------

Ľubomír Kučera <lubomir.kucera.jr at gmail.com>

COPYING
-------

Copyright \(C) 2018 Ľubomír Kučera. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
