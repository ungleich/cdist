cdist-type__consul(7)
=====================

NAME
----
cdist-type__consul - Install consul


DESCRIPTION
-----------
Downloads and installs the consul binary from https://dl.bintray.com/mitchellh/consul.
Note that the consul binary is downloaded on the server (the machine running
cdist) and then deployed to the target host using the __file type unless --direct
parameter is used.


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


BOOLEAN PARAMETERS
------------------
direct
    Download and deploy consul binary directly on the target machine.


MESSAGES
--------
If consul binary is created using __staged_file then underlaying __file type messages are emitted.

If consul binary is created by direct method then the following messages are emitted:

/usr/local/bin/consul created
    consul binary was created


EXAMPLES
--------

.. code-block:: sh

    # just install using defaults
    __consul

    # install by downloading consul binary directly on the target machine
    __consul --direct

    # specific version
    __consul \
       --version 0.4.1


AUTHORS
-------
| Steven Armstrong <steven-cdist--@--armstrong.cc>
| Darko Poljak <darko.poljak--@--gmail.com>


COPYING
-------
Copyright \(C) 2015 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
