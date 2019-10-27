cdist-type__xymon_server(7)
===========================

NAME
----
cdist-type__xymon_server - Install a Xymon server


DESCRIPTION
-----------
This cdist type installs a Xymon (https://www.xymon.com/) server and (optional)
required helper packages.

This includes the Xymon client as a dependency, so NO NEED to install
`__xymon_client` separately.

To access the webinterface a webserver is required.  The cdist-type
`__xymon_apache` can be used to install and configure the apache webserver for
the use with Xymon.

Further and day-to-day configuration of Xymon can either be done manually in
`/etc/xymon/` or the directory can be deployed and managed by `__xymon_config`.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
state
    'present', 'absent', defaults to 'present'. If '--install_helpers' is
    specified for 'absent' the helper packages will be un-installed.


BOOLEAN PARAMETERS
------------------
install_helpers
    Install helper packages used by Xymon (fping, heirloom-mailx, traceroute,
    ntpdate).


EXAMPLES
--------

.. code-block:: sh

    # minmal
    __xymon_server

    # the same
    __xymon_server --state present

    # also install helper packages:
    __xymon_server --install_helpers

    # examples to give a more complete picture: __xymon_server installed on
    # `xymon.example.com` w/ IP 192.168.1.1:
    #
    # install webserver and grant 2 private subnets access to the webinterface:
    __xymon_apache --ipacl "192.168.0.0/16 10.0.0.0/8"
    # deploy server-configuration with __xymon_config:
    __xymon_config --confdir=xymon.example.com

    # install xymon-client on other machines (not needed on the server):
    __xymon_client --servers "192.168.1.1"



SEE ALSO
--------
:strong:`cdist__xymon_apache`\ (7), :strong:`cdist__xymon_config`\ (7),
:strong:`cdist__xymon_client`\ (7), :strong:`xymon`\ (7)


AUTHORS
-------
Thomas Eckert <tom--@--it-eckert.de>


COPYING
-------
Copyright \(C) 2018-2019 Thomas Eckert. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
