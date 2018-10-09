cdist-type__docker_swarm(7)
===========================

NAME
----

cdist-type__docker_swarm - Manage Swarm

DESCRIPTION
-----------

This type can initialize Docker swarm mode. For more information about swarm
mode, see `Swarm mode overview <https://docs.docker.com/engine/swarm/>`_.

OPTIONAL PARAMETERS
-------------------

state
    'present' or 'absent', defaults to 'present' where:

    present
        Swarm is initialized
    absent
        Swarm is left

EXAMPLES
--------

.. code-block:: sh

    # Initializes a swarm
    __docker_swarm

    # Leaves a swarm
    __docker_swarm --state absent


AUTHORS
-------

Ľubomír Kučera <lubomir.kucera.jr at gmail.com>

COPYING
-------

Copyright \(C) 2018 Ľubomír Kučera. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
