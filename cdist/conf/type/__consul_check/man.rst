cdist-type__consul_check(7)
=============================

NAME
----
cdist-type__consul_check - Manages consul checks


DESCRIPTION
-----------
Generate and deploy check definitions for a consul agent.
See http://www.consul.io/docs/agent/checks.html for parameter documentation.

Use either script together with interval, or use ttl.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
docker-container-id
   the id of the docker container to run

http
   the url to check

id
   The id of this check.

interval
   the interval in which the check should run

name
   The name of this check. Defaults to __object_id

notes
   human readable description

script
   the shell command to run

service-id
   the id of the service this check is bound to

shell
   the shell to run inside the docker container

state
   if this check is 'present' or 'absent'. Defaults to 'present'.

status
   specify the initial state of this health check

tcp
   the host and port to check

timeout
   after how long to timeout checks which take to long

token
   ACL token to use for interacting with the catalog

ttl
   how long a TTL check is considered healthy without being updated through the
   HTTP interface


EXAMPLES
--------

.. code-block:: sh

    __consul_check redis \
       --script /usr/local/bin/check_redis.py \
       --interval 10s

    __consul_check some-object-id \
       --id web-app \
       --name "Web App Status" \
       --notes "Web app does a curl internally every 10 seconds" \
       --ttl 30s


SEE ALSO
--------
:strong:`cdist-type__consul_agent`\ (7)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2015-2016 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
