cdist-type__iptables_rule(7)
============================

NAME
----
cdist-type__iptables_rule - Deploy iptable rulesets


DESCRIPTION
-----------
This cdist type allows you to manage iptable rules
in a distribution independent manner.


REQUIRED PARAMETERS
-------------------
rule
    The rule to apply. Essentially an iptables command
    line without iptables in front of it.


OPTIONAL PARAMETERS
-------------------
state
   'present' or 'absent', defaults to 'present'


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


SEE ALSO
--------
:strong:`cdist-type__iptables_apply`\ (7), :strong:`iptables`\ (8)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2013 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
