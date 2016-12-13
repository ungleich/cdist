cdist-type__docker_compose(7)
=============================

NAME
----
cdist-type__docker_compose - install docker-compose


DESCRIPTION
-----------
Installs latest docker-compose package from dockerproject.org.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
version
   Define docker_compose version.


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

    __docker_compose

    # Install version 1.9.0-rc4
    __docker_compose --version 1.9.0-rc4


AUTHORS
-------
Dominique Roux <dominique.roux--@--ungleich.ch>


COPYING
-------
Copyright \(C) 2016 Dominique Roux. Free use of this software is
granted under the terms of the GNU General Public License version 3 or later (GPLv3+).
