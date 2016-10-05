cdist-type__pf_apply(7)
=======================

NAME
----
cdist-type__pf_apply - Apply pf(4) ruleset on \*BSD


DESCRIPTION
-----------
This type is used on \*BSD systems to manage the pf firewall's active ruleset.


REQUIRED PARAMETERS
-------------------
NONE


OPTIONAL PARAMETERS
-------------------
NONE


EXAMPLES
--------

.. code-block:: sh

    # Modify the ruleset on $__target_host:
    __pf_ruleset --state present --source /my/pf/ruleset.conf
    require="__pf_ruleset" \
       __pf_apply

    # Remove the ruleset on $__target_host (implies disabling pf(4):
    __pf_ruleset --state absent
    require="__pf_ruleset" \
       __pf_apply


SEE ALSO
--------
:strong:`pf`\ (4), :strong:`cdist-type__pf_ruleset`\ (7)


AUTHORS
-------
Jake Guffey <jake.guffey--@--eprotex.com>


COPYING
-------
Copyright \(C) 2012 Jake Guffey. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
