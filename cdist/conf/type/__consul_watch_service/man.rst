cdist-type__consul_watch_service(7)
===================================

NAME
----
cdist-type__consul_watch_service - Manages consul service watches


DESCRIPTION
-----------
Generate and deploy watch definitions of type 'service' for a consul agent.
See http://www.consul.io/docs/agent/watches.html for parameter documentation.


REQUIRED PARAMETERS
-------------------
handler
   the handler to invoke when the data view updates

service
   the service to watch for changes


OPTIONAL PARAMETERS
-------------------
datacenter
   can be provided to override the agent's default datacenter

state
   if this watch is 'present' or 'absent'. Defaults to 'present'.

token
   can be provided to override the agent's default ACL token

tag
   filter by tag


BOOLEAN PARAMETERS
------------------
passingonly
   specifies if only hosts passing all checks are displayed


EXAMPLES
--------

.. code-block:: sh

    __consul_watch_service some-id \
       --service consul \
       --handler /usr/bin/my-handler.sh

    __consul_watch_service some-id \
       --service redis \
       --tag production \
       --handler /usr/bin/my-handler.sh

    __consul_watch_service some-id \
       --service redis \
       --tag production \
       --passingonly \
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
