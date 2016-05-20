cdist-type__pf_apply(7)
=======================
Apply pf(4) ruleset on \*BSD

Jake Guffey <jake.guffey--@--eprotex.com>


NAME
----


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
- `cdist-type(7) <cdist-type.html>`_
- `cdist-type__pf_ruleset(7) <cdist-type__pf_ruleset.html>`_
- pf(4)


COPYING
-------
Copyright \(C) 2012 Jake Guffey. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
