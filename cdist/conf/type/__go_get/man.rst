cdist-type__go_get(7)
=====================

NAME
----
cdist-type__go_get - Install go packages with go get


DESCRIPTION
-----------
This cdist type allows you to install golang packages with go get.
A sufficiently recent version of go must be present on the system.

The object ID is the go package to be installed.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
None.


EXAMPLES
--------

.. code-block:: sh

    __go_get github.com/prometheus/prometheus/cmd/...

    # usually you'd need to require golang from somewhere:
    require="__golang_from_vendor" __go_get github.com/prometheus/prometheus/cmd/...


AUTHORS
-------
Kamila Součková <kamila@ksp.sk>


COPYING
-------
Copyright \(C) 2017 Kamila Součková. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
