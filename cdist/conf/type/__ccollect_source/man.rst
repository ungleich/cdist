cdist-type__ccollect_source(7)
==============================

NAME
----
cdist-type__ccollect_source - Manage ccollect sources


DESCRIPTION
-----------
This cdist type allows you to create or delete ccollect sources.


REQUIRED PARAMETERS
-------------------
source
    The source from which to backup
destination
    The destination directory


OPTIONAL PARAMETERS
-------------------
state
    'present' or 'absent', defaults to 'present'
ccollectconf
    The CCOLLECT_CONF directory. Defaults to /etc/ccollect.


OPTIONAL MULTIPLE PARAMETERS
----------------------------
exclude
    Paths to exclude of backup


BOOLEAN PARAMETERS
------------------
verbose
    Whether to report backup verbosely


EXAMPLES
--------

.. code-block:: sh

    __ccollect_source doc.ungleich.ch \
        --source doc.ungleich.ch:/ \
        --destination /backup/doc.ungleich.ch \
        --exclude '/proc/*' --exclude '/sys/*' \
        --verbose


SEE ALSO
--------
:strong:`ccollect`\ (1)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2014 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
