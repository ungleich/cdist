cdist-type__hwclock(7)
======================

NAME
----
cdist-type__hwclock - Manage the hardware real time clock.


DESCRIPTION
-----------
This type can be used to control how the hardware clock is used by the operating
system.


REQUIRED PARAMETERS
-------------------
mode
    What mode the hardware clock is in.

    Acceptable values:

    localtime
        The hardware clock is set to local time (common for systems also running
        Windows.)
    UTC
        The hardware clock is set to UTC (common on UNIX systems.)


OPTIONAL PARAMETERS
-------------------
None.


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

    # Make the operating system treat the time read from the hwclock as UTC.
    __hwclock --mode UTC


SEE ALSO
--------
:strong:`hwclock`\ (8)


AUTHORS
-------
Dennis Camera <dennis.camera@ssrq-sds-fds.ch>


COPYING
-------
Copyright \(C) 2020 Dennis Camera. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
