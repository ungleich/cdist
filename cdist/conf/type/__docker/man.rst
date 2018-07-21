cdist-type__docker(7)
=====================

NAME
----
cdist-type__docker - install Docker CE


DESCRIPTION
-----------
Installs latest Docker Community Edition package.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
state
   'present' or 'absent', defaults to 'present'


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

    # Install docker
    __docker

    # Remove docker
    __docker --state absent


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2016 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
