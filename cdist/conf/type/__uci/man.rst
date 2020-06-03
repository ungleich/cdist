cdist-type__uci(7)
==================

NAME
----
cdist-type__uci - Manage configuration values in OpenWrt's
Unified Configuration Interface (UCI)


DESCRIPTION
-----------
This cdist type can be used to alter configuration options in OpenWrt's UCI
system.

Options can be applied in batches if the `--transaction` parameter is used.
It is important to ensure that the `__uci_commit` object is executed before a
new transaction is started.

REQUIRED PARAMETERS
-------------------
value
    The value to be set. Can be used multiple times.
    This parameter is allowed to be omitted if `--state` is `absent`.

    Due to the way cdist handles arguments, values **must not** contain newline
    characters.


OPTIONAL PARAMETERS
-------------------
state
    `present` or `absent`, defaults to `present`.
transaction
    The name of the transaction this option belongs to.
    If none is given: "default" is used.


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

    # Set the system hostname
    __uci system.@system[0].hostname --value 'OpenWrt'

    # Enable NTP and NTPd (in one transaction)
    __uci system.ntp.enabled --value 1 --transaction ntp
    __uci system.ntp.enable_server --value 1 --transaction ntp
    __uci system.ntp.server --transaction ntp \
        --value '0.openwrt.pool.ntp.org' \
        --value '1.openwrt.pool.ntp.org' \
        --value '2.openwrt.pool.ntp.org' \
        --value '3.openwrt.pool.ntp.org'
    export require=__uci_commit/ntp


SEE ALSO
--------
- https://openwrt.org/docs/guide-user/base-system/uci
- :strong:`cdist-type__uci_commit`\ (7)


AUTHORS
-------
Dennis Camera <dennis.camera@ssrq-sds-fds.ch>


COPYING
-------
Copyright \(C) 2020 Dennis Camera. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
