cdist-type__consul_watch_keyprefix(7)
=====================================

NAME
----
cdist-type__consul_watch_keyprefix - Manages consul keyprefix watches


DESCRIPTION
-----------
Generate and deploy watch definitions of type 'keyprefix' for a consul agent.
See http://www.consul.io/docs/agent/watches.html for parameter documentation.


REQUIRED PARAMETERS
-------------------
handler
   the handler to invoke when the data view updates

prefix
   the prefix of keys to watch for changes


OPTIONAL PARAMETERS
-------------------
datacenter
   can be provided to override the agent's default datacenter

state
   if this watch is 'present' or 'absent'. Defaults to 'present'.

token
   can be provided to override the agent's default ACL token


EXAMPLES
--------

.. code-block:: sh

    __consul_watch_keyprefix some-id \
       --prefix foo/ \
       --handler /usr/bin/my-prefix-handler.sh


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
