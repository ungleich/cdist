cdist-type__docker(7)
=====================

NAME
----
cdist-type__docker - install docker-engine


DESCRIPTION
-----------
Installs latest docker-engine package from dockerproject.org.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
None.


BOOLEAN PARAMETERS
------------------
experimental
   Install the experimental docker-engine package instead of the latest stable release.

state
   'present' or 'absent', defaults to 'present'


EXAMPLES
--------

.. code-block:: sh

    # Install docker
    __docker

    # Install experimental
    __docker --experimental

    # Remove docker
    __docker --state absent


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2016 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
