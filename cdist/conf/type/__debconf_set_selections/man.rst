cdist-type__debconf_set_selections(7)
=====================================

NAME
----
cdist-type__debconf_set_selections - Setup debconf selections


DESCRIPTION
-----------
On Debian and alike systems debconf-set-selections(1) can be used
to setup configuration parameters.


REQUIRED PARAMETERS
-------------------
file
   Use the given filename as input for debconf-set-selections(1)
   If filename is "-", read from stdin.


EXAMPLES
--------

.. code-block:: sh

    # Setup configuration for nslcd
    __debconf_set_selections nslcd --file /path/to/file

    # Setup configuration for nslcd from another type
    __debconf_set_selections nslcd --file "$__type/files/preseed/nslcd"

    __debconf_set_selections nslcd --file - << eof
    gitolite gitolite/gituser string git
    eof


SEE ALSO
--------
:strong:`debconf-set-selections`\ (1), :strong:`cdist-type__update_alternatives`\ (7)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2011-2014 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
