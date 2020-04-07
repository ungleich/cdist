cdist-type__coturn(7)
=====================

NAME
----
cdist-type__coturn - Install and configure a coturn TURN server


DESCRIPTION
-----------
This (singleton) type install and configure a coturn TURN
server.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
static_auth_secret
  Secret used to access the TURN REST API.

realm
  Defailt realm.

BOOLEAN PARAMETERS
------------------
use_auth_secret
  Allows TURN credentials to be accounted for a specific user id.

no_tcp_relay
  Disable TCP relay endpoints.


EXAMPLES
--------

.. code-block:: sh

    __coturn \
      --realm turn.domain.tld \
      --no_tcp_relay


SEE ALSO
--------
- `coturn Github repository <https://github.com/coturn/coturn>`_

AUTHORS
-------
Timothée Floure <timothee.floure@ungleich.ch>


COPYING
-------
Copyright \(C) 2020 Timothée Floure. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
