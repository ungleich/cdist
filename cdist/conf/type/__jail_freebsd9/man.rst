cdist-type__jail_freebsd9(7)
============================

NAME
----
cdist-type__jail_freebsd9 - Manage FreeBSD jails


DESCRIPTION
-----------
This type is used on FreeBSD <= 9.x to manage jails.


REQUIRED PARAMETERS
-------------------
state
   Either "present" or "absent", defaults to "present".

jailbase
   The location of the .tgz archive containing the base fs for your jails.


OPTIONAL PARAMETERS
-------------------
name
   The name of the jail. Default is to use the object_id as the jail name.

ip
   The ifconfig style IP/netmask combination to use for the jail guest. If
   the state parameter is "present," this parameter is required.

hostname
   The FQDN to use for the jail guest. Defaults to the name parameter.

interface
   The name of the physical interface on the jail server to bind the jail to.
   Defaults to the first interface found in the output of ifconfig -l.

devfs-ruleset
   The name of the devfs ruleset to associate with the jail. Defaults to
   "jailrules." This ruleset must be copied to the server via another type.
   To use this option, devfs-enable must be "true."

jaildir
   The location on the remote server to use for hosting jail filesystems.
   Defaults to /usr/jail.

BOOLEAN PARAMETERS
------------------
stopped
   Do not start the jail

devfs-disable
   Whether to disallow devfs mounting within the jail

onboot
   Whether to add the jail to rc.conf's jail_list variable. 


CAVEATS
-------
This type does not currently support modification of jail options. If, for
example a jail needs to have its IP address or netmask changed, the jail must
be removed then re-added with the correct IP address/netmask or the appropriate
line (jail_<name>_ip="...") modified within rc.conf through some alternate
means.

MESSAGES
--------
start
   The jail was started
stop
   The jail was stopped
create:
   The jail was created
delete
   The jail was deleted
onboot
   The jail was configured to start on boot

EXAMPLES
--------

.. code-block:: sh

    # Create a jail called www
    __jail_freebsd9 www --state present --ip "192.168.1.2" --jailbase /my/jail/base.tgz

    # Remove the jail called www
    __jail_freebsd9 www --state absent --jailbase /my/jail/base.tgz

    # The jail www should not be started
    __jail_freebsd9 www --state present --stopped \
       --ip "192.168.1.2 netmask 255.255.255.0" \
       --jailbase /my/jail/base.tgz

    # Use the name variable explicitly
    __jail_freebsd9 thisjail --state present --name www \
       --ip "192.168.1.2" \
       --jailbase /my/jail/base.tgz

    # Go nuts
    __jail_freebsd9 lotsofoptions --state present --name testjail \
       --ip "192.168.1.100 netmask 255.255.255.0" \
       --hostname "testjail.example.com" --interface "em0" \
       --onboot --jailbase /my/jail/base.tgz --jaildir /jails


SEE ALSO
--------
:strong:`jail`\ (8)


AUTHORS
-------
Jake Guffey <jake.guffey--@--eprotex.com>


COPYING
-------
Copyright \(C) 2012-2016 Jake Guffey. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
