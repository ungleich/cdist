cdist-type__docker_stack(7)
===========================

NAME
----

cdist-type__docker_stack - Manage Docker stacks

DESCRIPTION
-----------

This type manages service stacks.

.. note::
    Since there is no easy way to tell whether a stack needs to be updated,
    `docker stack deploy` is being run every time this type is invoked.
    However, it does not mean this type is not idempotent. If Docker does not
    detect changes, the existing stack will not be updated.

OPTIONAL PARAMETERS
-------------------

compose-file
    Path to the compose file. If it is '-' (dash), read standard input.

state
    'present' or 'absent', defaults to 'present' where:

    present
        the stack is deployed
    absent
        the stack is removed

EXAMPLES
--------

.. code-block:: sh

    # Deploys 'foo' stack defined in 'docker-compose.yml' compose file
    __docker_stack foo --compose-file docker-compose.yml


AUTHORS
-------

Ľubomír Kučera <lubomir.kucera.jr at gmail.com>

COPYING
-------

Copyright \(C) 2018 Ľubomír Kučera. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
