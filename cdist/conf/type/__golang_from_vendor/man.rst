cdist-type__golang_from_vendor(7)
=================================

NAME
----
cdist-type__golang_from_vendor - Install any version of golang from golang.org


DESCRIPTION
-----------
This cdist type allows you to install golang from archives provided by https://golang.org/dl/.

See https://golang.org/dl/ for the list of supported versions, operating systems and architectures.

This is a singleton type.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
version
    The golang version to install, defaults to 1.8.1


EXAMPLES
--------

.. code-block:: sh

    __golang_from_vendor --version 1.8.1



AUTHORS
-------
Kamila Součková <kamila@ksp.sk>


COPYING
-------
Copyright \(C) 2017 Kamila Součková. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
