cdist-type__firewalld_rule(7)
=============================

NAME
----
cdist-type__firewalld_rule - Configure firewalld rules


DESCRIPTION
-----------
This cdist type allows you to manage rules in firewalld
using the *direct* way (i.e. no zone support).


REQUIRED PARAMETERS
-------------------
rule
    The rule to apply. Essentially an firewalld command
    line without firewalld in front of it.
protocol
    Either ipv4, ipv4 or eb. See firewall-cmd(1)
table
    The table to use (like filter or nat). See firewall-cmd(1).
chain
    The chain to use (like INPUT_direct or FORWARD_direct). See firewall-cmd(1).
priority
    The priority to use (0 is topmost). See firewall-cmd(1).


OPTIONAL PARAMETERS
-------------------
state
   'present' or 'absent', defaults to 'present'


EXAMPLES
--------

.. code-block:: sh

    # Allow access from entrance.place4.ungleich.ch
    __firewalld_rule entrance \
        --protocol ipv4 \
        --table filter \
        --chain INPUT_direct \
        --priority 0 \
        --rule '-s entrance.place4.ungleich.ch -j ACCEPT'

    # Allow forwarding of traffic from br0
    __firewalld_rule vm-forward --protocol ipv4 \
        --table filter \
        --chain FORWARD_direct \
        --priority 0 \
        --rule '-i br0 -j ACCEPT'

    # Ensure old rule is absent - warning, the rule part must stay the same!
    __firewalld_rule vm-forward
        --protocol ipv4 \
        --table filter \
        --chain FORWARD_direct \
        --priority 0 \
        --rule '-i br0 -j ACCEPT' \
        --state absent


SEE ALSO
--------
:strong:`cdist-type__iptables_rule`\ (7), :strong:`firewalld`\ (8)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2015 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
