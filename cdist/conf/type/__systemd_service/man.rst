cdist-type__systemd_service(7)
==============================

NAME
----
cdist-type__systemd_service - Controls a systemd service state


DESCRIPTION
-----------
This type controls systemd services to define a state of the service,
or an action like reloading or restarting. It is useful to reload a
service after configuration applied or shutdown one service.

The activation or deactivation is out of scope. Look for the
:strong:`cdist-type__systemd_util`\ (7) type instead.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------

name
    String which will used as name instead of the object id.

state
    The state which the service should be in:

    running
        Service should run (default)

    stopped
        Service should be stopped

action
    Executes an action on on the service. It will only execute it if the
    service keeps the state ``running``. There are following actions, where:

    reload
        Reloads the service

    restart
        Restarts the service

BOOLEAN PARAMETERS
------------------

if-required
    Only execute the action if at minimum one required type outputs a message
    to ``$__messages_out``. Through this, the action should only executed if a
    dependency did something. The action will not executed if no dependencies
    given.


MESSAGES
--------

start
    Started the service

stop
    Stopped the service

restart
    Restarted the service

reload
    Reloaded the service


ABORTS
------
Aborts in following cases:

systemd or the service does not exist


EXAMPLES
--------
.. code-block:: sh

    # service must run
    __systemd_service nginx

    # service must stopped
    __systemd_service sshd \
        --state stopped

    # restart the service
    __systemd_service apache2 \
        --action restart

    # makes sure the service exist with an alternative name
    __systemd_service foo \
        --name sshd

    # reload the service for a modified configuration file
    # only reloads the service if the file really changed
    require="__file/etc/foo.conf" __systemd_service foo \
        --action reload --if-required


AUTHORS
-------
Matthias Stecher <matthiasstecher at gmx.de>


COPYRIGHT
---------
Copyright \(C) 2020 Matthias Stecher. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
