cdist-type__uci_section(7)
==========================

NAME
----
cdist-type__uci_section - Manage configuration sections in OpenWrt's
Unified Configuration Interface (UCI)


DESCRIPTION
-----------
This cdist type can be used to replace whole configuration sections in OpenWrt's
UCI system.
It can be thought of as syntactic sugar for `cdist-type__uci`\ (7), as this type
will generate the required `__uci` objects to make the section contain exactly
the options specified via ``--option``.

Since many default UCI sections are unnamed, this type allows to find the
matching section by one of its options using the ``--match`` parameter.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
match
    Allows to find a section to "replace" through one of its parameters.
    The value to this parameter is a ``<option>=<string>`` string.
option
    An option that should be present in the section.
    This parameter can be used multiple times to specify multiple options.
    The value to this parameter is a ``<option>=<string>`` string.

    Lists can be expressed by repeatedly using the same key.
state
    `present` or `absent`, defaults to `present`.
transaction
    The name of the transaction this option belongs to.
    The value will be forwarded to `cdist-type__uci`\ (7).
type
    The type of the section in the format: ``<config>.<section-type>``


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

    # TODO
    __uci_section ...


SEE ALSO
--------
:strong:`cdist-type__uci`\ (7)


AUTHORS
-------
Dennis Camera <dennis.camera@ssrq-sds-fds.ch>


COPYING
-------
Copyright \(C) 2020 Dennis Camera. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
