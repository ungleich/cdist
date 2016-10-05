cdist-type__consul_watch_checks(7)
==================================

NAME
----
cdist-type__consul_watch_checks - Manages consul checks watches


DESCRIPTION
-----------
Generate and deploy watch definitions of type 'checks' for a consul agent.
See http://www.consul.io/docs/agent/watches.html for parameter documentation.


REQUIRED PARAMETERS
-------------------
handler
   the handler to invoke when the data view updates


OPTIONAL PARAMETERS
-------------------
datacenter
   can be provided to override the agent's default datacenter

filter-service
   filter to a specific service. Conflicts with --filter-state.

filter-state
   filter to a specific state. Conflicts with --filter-service.

state
   if this watch is 'present' or 'absent'. Defaults to 'present'.

token
   can be provided to override the agent's default ACL token


EXAMPLES
--------

.. code-block:: sh

    __consul_watch_checks some-id \
       --handler /usr/bin/my-handler.sh

    __consul_watch_checks some-id \
       --filter-service consul \
       --handler /usr/bin/my-handler.sh

    __consul_watch_checks some-id \
       --filter-state passing \
       --handler /usr/bin/my-handler.sh


SEE ALSO
--------
:strong:`cdist-type__consul_agent`\ (7)

consul documentation at: <http://www.consul.io/docs/agent/watches.html>.


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2015 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
