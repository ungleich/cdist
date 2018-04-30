cdist-type__docker_secret(7)
============================

NAME
----

cdist-type__docker_secret - Manage Docker secrets

DESCRIPTION
-----------

This type manages Docker secrets.

OPTIONAL PARAMETERS
-------------------

source
    Path to the source file. If it is '-' (dash), read standard input.

state
    'present' or 'absent', defaults to 'present' where:

    present
        if the secret does not exist, it is created
    absent
        the secret is removed

CAVEATS
-------

Since Docker secrets cannot be updated once created, this type takes no action
if the specified secret already exists.

EXAMPLES
--------

.. code-block:: sh

    # Creates "foo" secret from "bar" source file
    __docker_secret foo --source bar


AUTHORS
-------

Ľubomír Kučera <lubomir.kucera.jr at gmail.com>

COPYING
-------

Copyright \(C) 2018 Ľubomír Kučera. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
