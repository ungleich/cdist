cdist-type__iptables_apply(7)
=============================

NAME
----
cdist-type__iptables_apply - Apply the rules


DESCRIPTION
-----------
This cdist type deploys an init script that triggers
the configured rules and also re-applies them on
configuration. Rules are written from __iptables_rule
into the folder ``/etc/iptables.d/``.

It reads all rules from the base folder as rules for IPv4.
Rules in the subfolder ``v6/`` are IPv6 rules. Rules in
the subfolder ``all/`` are applied to both rule tables. All
files contain the arguments for a single ``iptables`` and/or
``ip6tables`` command.

Rules are applied in the following order:
1. All IPv4 rules
2. All IPv6 rules
2. All rules that should be applied to both tables

The order of the rules that will be applied are definite
from the result the shell glob returns, which should be
alphabetical. If rules must be applied in a special order,
prefix them with a number like ``02-some-rule``.


REQUIRED PARAMETERS
-------------------
None

OPTIONAL PARAMETERS
-------------------
None

EXAMPLES
--------

None (__iptables_apply is used by __iptables_rule automatically)


SEE ALSO
--------
:strong:`cdist-type__iptables_rule`\ (7), :strong:`iptables`\ (8)


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
