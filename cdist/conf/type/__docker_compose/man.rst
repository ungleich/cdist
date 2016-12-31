cdist-type__docker_compose(7)
=============================

NAME
----
cdist-type__docker_compose - install docker-compose


DESCRIPTION
-----------
Installs docker-compose package.
State 'absent' will not remove docker binary itself,
only docker-compose binary will be removed


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
version
   Define docker_compose version, defaults to "1.9.0" 

state
   'present' or 'absent', defaults to 'present'


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

    # Install docker-compose
    __docker_compose

    # Install version 1.9.0-rc4
    __docker_compose --version 1.9.0-rc4

    # Remove docker-compose 
    __docker_compose --state absent


AUTHORS
-------
Dominique Roux <dominique.roux--@--ungleich.ch>


COPYING
-------
Copyright \(C) 2016 Dominique Roux. Free use of this software is
granted under the terms of the GNU General Public License version 3 or later (GPLv3+).
