cdist-type__ufw(7)
==================

NAME
----
cdist-type__ufw - Install the Uncomplicated FireWall


DESCRIPTION
-----------
Installs the Uncomplicated FireWall. Most modern distributions carry UFW in their main repositories, but on CentOS this type will automatically enable the EPEL repository.

Some global configuration can also be set with this type.

OPTIONAL PARAMETERS
-------------------
state
    Either "enabled", "running", "present", or "absent". Defaults to "enabled", which registers UFW to start on boot.

logging
    Either "off", "low", "medium", "high", or "full". Will be passed to `ufw logging`. If not specified, logging level is not modified.

default_incoming
    Either "allow", "deny", or "reject". The default policy for dealing with ingress packets.
    
default_outgoing
    Either "allow", "deny", or "reject". The default policy for dealing with egress packets.
    
default_routed
    Either "allow", "deny", or "reject". The default policy for dealing with routed packets (passing through this machine).
    

EXAMPLES
--------

.. code-block:: sh

    # Install UFW
    __ufw
    # Setup UFW with maximum logging and no restrictions on routed packets.
    __ufw --logging full --default_routed allow


SEE ALSO
--------
:strong:`ufw`\ (8)


AUTHORS
-------
Mark Polyakov <mark@markasoftware.com>


COPYING
-------
Copyright \(C) 2019 Mark Polyakov. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
