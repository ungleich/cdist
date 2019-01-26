cdist-type__cdist_preos_trigger(7)
==================================

NAME
----
cdist-type__cdist_preos_trigger - configure cdist preos trigger


DESCRIPTION
-----------
Create cdist PreOS trigger by creating systemd unit file that will be started
at boot and will execute trigger command - connect to specified host and port.


REQUIRED PARAMETERS
-------------------
trigger-command
    Command that will be executed as a PreOS cdist trigger.


OPTIONAL PARAMETERS
-------------------
None


EXAMPLES
--------

.. code-block:: sh

    # Configure default curl trigger for host cdist.ungleich.ch at port 80.
    __cdist_preos_trigger http --trigger-command '/usr/bin/curl cdist.ungleich.ch:80'


AUTHORS
-------
Darko Poljak <darko.poljak--@--ungleich.ch>


COPYING
-------
Copyright \(C) 2016 Darko Poljak. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
