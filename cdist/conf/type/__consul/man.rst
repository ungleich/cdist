cdist-type__consul(7)
=====================

NAME
----
cdist-type__consul - Install consul


DESCRIPTION
-----------
Downloads and installs the consul binary from https://dl.bintray.com/mitchellh/consul.
Note that the consul binary is downloaded on the server (the machine running
cdist) and then deployed to the target host using the __file type.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
state
   either 'present' or 'absent'. Defaults to 'present'

version
   which version of consul to install. See ./files/versions for a list of
   supported versions. Defaults to the latest known version.


EXAMPLES
--------

.. code-block:: sh

    # just install using defaults
    __consul

    # specific version
    __consul \
       --version 0.4.1


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2015 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
