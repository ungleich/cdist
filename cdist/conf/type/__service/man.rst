cdist-type__service(7)
======================

NAME
----
cdist-type__service - Run action on a system service


DESCRIPTION
-----------
This type allows you to run an action against a system service.


REQUIRED PARAMETERS
-------------------
action
  Arbitrary parameter passed as action. Usually 'start', 'stop', 'reload' or 'restart'.

OPTIONAL PARAMETERS
-------------------
None.


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

    # Restart nginx service.
    __service nginx --action restart

    # Stop postfix service.
    __service postfix --action stop


AUTHORS
-------
Timothée Floure <timothee.floure@ungleich.ch>


COPYING
-------
Copyright \(C) 2019 Timothée Floure. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
