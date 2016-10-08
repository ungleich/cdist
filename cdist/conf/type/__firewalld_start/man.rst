cdist-type__firewalld_start(7)
==============================

NAME
----
cdist-type__firewalld_start - start and enable firewalld


DESCRIPTION
-----------
This cdist type allows you to start and enable firewalld.


REQUIRED PARAMETERS
-------------------
None

OPTIONAL PARAMETERS
-------------------
startstate
    'present' or 'absent', start/stop firewalld. Default is 'present'.
bootstate
    'present' or 'absent', enable/disable firewalld on boot. Default is 'present'.


EXAMPLES
--------

.. code-block:: sh

    # start and enable firewalld
    __firewalld_start

    # only enable firewalld to start on boot
    __firewalld_start --startstate present --bootstate absent


SEE ALSO
--------
:strong:`firewalld`\ (8)


AUTHORS
-------
Darko Poljak <darko.poljak--@--ungleich.ch>


COPYING
-------
Copyright \(C) 2016 Darko Poljak. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
