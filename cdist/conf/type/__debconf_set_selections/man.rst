cdist-type__debconf_set_selections(7)
=====================================
Setup debconf selections

Nico Schottelius <nico-cdist--@--schottelius.org>


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
- `cdist-type(7) <cdist-type.html>`_
- `cdist-type__update_alternatives(7) <cdist-type__update_alternatives.html>`_
- debconf-set-selections(1)


COPYING
-------
Copyright \(C) 2011-2014 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
