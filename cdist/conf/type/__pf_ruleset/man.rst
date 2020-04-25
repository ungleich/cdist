cdist-type__pf_ruleset(7)
=========================

NAME
----
cdist-type__pf_ruleset - Copy a pf(4) ruleset to $__target_host


DESCRIPTION
-----------
This type is used on \*BSD systems to manage the pf firewall's ruleset.

It will also enable and disable the pf firewall as requested in the `state`
parameter.


REQUIRED PARAMETERS
-------------------
state
   Either "absent" (no ruleset at all) or "present", defaults to "present".


OPTIONAL PARAMETERS
-------------------
source
   Required when state is "present".
   Defines the ruleset to load onto the $__target_host for `pf(4)`.


EXAMPLES
--------

.. code-block:: sh

    # Remove the current ruleset in place and disable pf
    __pf_ruleset --state absent

    # Enable pf with the ruleset defined in $__manifest/files/pf.conf
    __pf_ruleset --state present --source $__manifest/files/pf.conf


SEE ALSO
--------
:strong:`pf`\ (4)


AUTHORS
-------
Kamila Součková <coding--@--kamila.is>
Jake Guffey <jake.guffey--@--eprotex.com>


COPYING
-------
Copyright \(C) 2016 Kamila Součková.
Copyright \(C) 2012 Jake Guffey. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
