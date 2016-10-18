cdist-type__install_stage(7)
============================

NAME
----
cdist-type__install_stage - download and unpack a stage file


DESCRIPTION
-----------
Downloads a operating system stage using curl and unpacks it to /target
using tar. The stage tarball is expected to be gzip compressed.


REQUIRED PARAMETERS
-------------------
uri
   The uri from which to fetch the tarball.
   Can be anything understood by curl, e.g:
     | http://path/to/stage.tgz
     | tftp:///path/to/stage.tgz
     | file:///local/path/stage.tgz


OPTIONAL PARAMETERS
-------------------
target
   where to unpack the tarball to. Defaults to /target.


BOOLEAN PARAMETERS
------------------
insecure
   run curl in insecure mode so it does not check the servers ssl certificate


EXAMPLES
--------

.. code-block:: sh

    __install_stage --uri tftp:///path/to/stage.tgz
    __install_stage --uri http://path/to/stage.tgz --target /mnt/foobar
    __install_stage --uri file:///path/to/stage.tgz --target /target
    __install_stage --uri https://path/to/stage.tgz --target /mnt/foobar --insecure


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 - 2013 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
