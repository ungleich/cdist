cdist-type__pf_apply_anchor(7)
==============================

NAME
----
cdist-type__pf_apply_anchor - Apply a pf(4) anchor on $__target_host


DESCRIPTION
-----------
This type is used on \*BSD systems to manage anchors for the pf firewall.

Notice this type does not take care of copying the ruleset, that must be
done by the user with, e.g. `__file`.


OPTIONAL PARAMETERS
-------------------
anchor_name
   The name of the anchor to apply. If not set, `${__object_id}` is used.
   This type requires `/etc/pf.d/${anchor_name}` to exist on
   `$__target_host`.


EXAMPLES
--------

.. code-block:: sh

    # Copy anchor file to ${__target_host}
    __file "/etc/pf.d/80_dns" --source - <<EOF
    # Managed remotely, changes will be lost

    pass quick proto {tcp,udp} from any to any port domain
    EOF

    # Apply the anchor
    require="__file/etc/pf.d/80_dns" __pf_apply_anchor 80_dns
    # This is roughly equivalent to:
    #   pfctl -a "${anchor_name}" -f "/etc/pf.d/${anchor_name}"


SEE ALSO
--------
:strong:`pf`\ (4)


AUTHORS
-------
Evilham <contact--@--evilham.com>
Kamila Součková <coding--@--kamila.is>
Jake Guffey <jake.guffey--@--eprotex.com>


COPYING
-------
Copyright \(C) 2020 Evilham.
Copyright \(C) 2016 Kamila Součková.
Copyright \(C) 2012 Jake Guffey. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
