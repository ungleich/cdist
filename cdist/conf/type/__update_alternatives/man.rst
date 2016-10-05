cdist-type__update_alternatives(7)
==================================

NAME
----
cdist-type__update_alternatives - Configure alternatives


DESCRIPTION
-----------
On Debian and alike systems update-alternatives(1) can be used
to setup alternatives for various programs.
One of the most common used targets is the "editor".


REQUIRED PARAMETERS
-------------------
path
   Use this path for the given alternative


EXAMPLES
--------

.. code-block:: sh

    # Setup vim as the default editor
    __update_alternatives editor --path /usr/bin/vim.basic


SEE ALSO
--------
:strong:`cdist-type__debconf_set_selections`\ (7), :strong:`update-alternatives`\ (8)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2013 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
