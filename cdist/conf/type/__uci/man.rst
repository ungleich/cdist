cdist-type__uci(7)
==================

NAME
----
cdist-type__uci - Manage configuration values in UCI


DESCRIPTION
-----------
This cdist type can be used to alter configuration options in OpenWrt's
Unified Configuration Interface (UCI) system.


REQUIRED PARAMETERS
-------------------
value
    The value to be set. Can be used multiple times.
    This parameter is ignored if ``--state`` is ``absent``.

    Due to the way cdist handles arguments, values **must not** contain newline
    characters.

    Values do not need special quoting for UCI. The only requirement is that the
    value is passed to the type as a single shell argument.

OPTIONAL PARAMETERS
-------------------
state
    ``present`` or ``absent``, defaults to ``present``.
type
    If the type should generate an option or a list.
    One of: ``option`` or ``list``.
    Defaults to auto-detect based on the number of ``--value`` parameters.


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

    # Set the system hostname
    __uci system.@system[0].hostname --value 'OpenWrt'

    # Set DHCP option 252: tell DHCP clients to not ask for proxy information.
    __uci dhcp.lan.dhcp_option --type list --value '252,"\n"'

    # Enable NTP and NTPd (each is applied individually)
    __uci system.ntp.enabled --value 1
    __uci system.ntp.enable_server --value 1
    __uci system.ntp.server --type list \
        --value '0.openwrt.pool.ntp.org' \
        --value '1.openwrt.pool.ntp.org' \
        --value '2.openwrt.pool.ntp.org' \
        --value '3.openwrt.pool.ntp.org'


SEE ALSO
--------
- https://openwrt.org/docs/guide-user/base-system/uci


AUTHORS
-------
Dennis Camera <dennis.camera@ssrq-sds-fds.ch>


COPYING
-------
Copyright \(C) 2020 Dennis Camera. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
