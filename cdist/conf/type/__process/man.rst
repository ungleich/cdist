cdist-type__process(7)
======================

NAME
----
cdist-type__process - Start or stop process


DESCRIPTION
-----------
This cdist type allows you to define the state of a process.


OPTIONAL PARAMETERS
-------------------
state
    Either "present" or "absent", defaults to "present"

name
    Process name to match on when using pgrep -f -x.

    This is useful, if the name starts with a "/",
    because the leading slash is stripped away from
    the object id by cdist.

stop
    Executable to use for stopping the process.

start
    Executable to use for starting the process.


EXAMPLES
--------

.. code-block:: sh

    # Start if not running
    __process /usr/sbin/syslog-ng --state present

    # Start if not running with a different binary
    __process /usr/sbin/nginx --state present --start "/etc/rc.d/nginx start"

    # Stop the process using kill (the type default) - DO NOT USE THIS
    __process /usr/sbin/sshd --state absent

    # Stop the process using /etc/rc.d/sshd stop - THIS ONE NOT AS WELL
    __process /usr/sbin/sshd --state absent --stop "/etc/rc.d/sshd stop"

    # Ensure cups is running, which runs with -C ...:
    __process cups --start "/etc/rc.d/cups start" --state present \
       --name "/usr/sbin/cupsd -C /etc/cups/cupsd.conf"

    # Ensure rpc.statd is running (which usually runs with -L) using a regexp
    __process rpcstatd --state present --start "/etc/init.d/statd start" \
        --name "rpc.statd.*"


SEE ALSO
--------
:strong:`cdist-type__start_on_boot`\ (7)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2011-2012 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
