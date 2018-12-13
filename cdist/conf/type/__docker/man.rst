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
version
   The specific version to install. Defaults to the special value 'latest',
   meaning the version the package manager will install by default.


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

    # Install specific version
    __docker --state present --version 18.03.0.ce

AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2016 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
