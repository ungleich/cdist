cdist-type__ufw_rule(7)
=======================

NAME
----
cdist-type__ufw_rule - A single UFW rule


DESCRIPTION
-----------
Adds or removes a single UFW rule. This type supports adding and deleting rules for port ranges or applications.

Understanding what is "to" and what is "from" can be confusing. If the rule is ingress (default), then "from" is the remote machine and "to" is the local one. The opposite is true for egress traffic (--out).

OPTIONAL PARAMETERS
-------------------
state
    Either "present" or "absent". Defaults to "present". If "absent", only removes rules that exactly match the rule expected.

rule
    A firewall rule in UFW syntax. This is what you would usually write after `ufw` on the command line. Defaults to "allow" followed by the object ID. You can use either the short syntax (just allow|deny|reject|limit followed by a port or application name) or the full syntax. Do not include `delete` in your command. Set `--state absent` instead.

EXAMPLES
--------

.. code-block:: sh

    # open port 80 (ufw allow 80)
    __ufw_rule 80
    # Allow mosh application (if installed)
    __ufw_rule mosh
    # Allow all traffic from local network (ufw allow from 10.0.0.0/24)
    __ufw_rule local --rule 'allow from 10.0.0.0/24'
    # Block egress traffic from port 25 to 111.55.55.55 on interface eth0
    __ufw_rule block_smtp --rule 'deny out on eth0 from any port 25 to 111.55.55.55'


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
