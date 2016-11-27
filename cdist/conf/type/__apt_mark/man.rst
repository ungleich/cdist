cdist-type__apt_mark(7)
=======================

NAME
----
cdist-type__apt_mark - set package state as 'hold' or 'unhold'


DESCRIPTION
-----------
See apt-mark(8) for details.


REQUIRED PARAMETERS
-------------------
state
   Either "hold" or "unhold".


OPTIONAL PARAMETERS
-------------------
name
   If supplied, use the name and not the object id as the package name.


EXAMPLES
--------

.. code-block:: sh

    # hold package
    __apt_mark quagga --state hold
    # unhold package
    __apt_mark quagga --state unhold


AUTHORS
-------
Ander Punnar <cdist--@--kvlt.ee>


COPYING
-------
Copyright \(C) 2016 Ander Punnar. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
