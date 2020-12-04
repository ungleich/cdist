cdist-type__iptables_rule(7)
============================

NAME
----
cdist-type__iptables_rule - Deploy iptable rulesets


DESCRIPTION
-----------
This cdist type allows you to manage iptable rules
in a distribution independent manner.

See :strong:`cdist-type__iptables_apply`\ (7) for the
execution order of these rules. It will be executed
automaticly to apply all rules non-volaite.


REQUIRED PARAMETERS
-------------------
rule
    The rule to apply. Essentially an iptables command
    line without iptables in front of it.


OPTIONAL PARAMETERS
-------------------
state
   'present' or 'absent', defaults to 'present'


BOOLEAN PARAMETERS
------------------
All rules without any of these parameters will be treated like ``--v4`` because
of backward compatibility.

v4
    Explicitly set it as rule for IPv4. If IPv6 is set, too, it will be
    threaten like ``--all``. Will be the default if nothing else is set.

v6
    Explicitly set it as rule for IPv6. If IPv4 is set, too, it will be
    threaten like ``--all``.

all
    Set the rule for both IPv4 and IPv6. It will be saved separately from the
    other rules.


EXAMPLES
--------

.. code-block:: sh

    # Deploy some policies
    __iptables_rule policy-in  --rule "-P INPUT DROP"
    __iptables_rule policy-out  --rule "-P OUTPUT ACCEPT"
    __iptables_rule policy-fwd  --rule "-P FORWARD DROP"

    # The usual established rule
    __iptables_rule established  --rule "-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT"

    # Some service rules
    __iptables_rule http  --rule "-A INPUT -p tcp --dport 80 -j ACCEPT"
    __iptables_rule ssh   --rule "-A INPUT -p tcp --dport 22 -j ACCEPT"
    __iptables_rule https --rule "-A INPUT -p tcp --dport 443 -j ACCEPT"

    # Ensure some rules are not present anymore
    __iptables_rule munin --rule "-A INPUT -p tcp --dport 4949 -j ACCEPT" \
        --state absent


    # IPv4-only rule for ICMPv4
    __iptables_rule icmp-v4 --v4 --rule "-A INPUT -p icmp -j ACCEPT"
    # IPv6-only rule for ICMPv6
    __iptables_rule icmp-v6 --v6 --rule "-A INPUT -p icmpv6 -j ACCEPT"

    # doing something for the dual stack
    __iptables_rule fwd-eth0-eth1 --v4 --v6 --rule "-A INPUT -i eth0 -o eth1 -j ACCEPT"
    __iptables_rule fwd-eth1-eth0 --all --rule "-A -o eth1 -i eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT"


SEE ALSO
--------
:strong:`cdist-type__iptables_apply`\ (7), :strong:`iptables`\ (8)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>
Matthias Stecher <matthiasstecher--@--gmx.de>


COPYING
-------
Copyright \(C) 2013 Nico Schottelius.
Copyright \(C) 2020 Matthias Stecher.
You can redistribute it and/or modify it under the terms of the GNU
General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.
