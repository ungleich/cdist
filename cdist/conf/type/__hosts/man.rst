cdist-type__hosts(7)
====================

NAME
----

cdist-type__hosts - manage entries in /etc/hosts

DESCRIPTION
-----------

Add or remove entries from */etc/hosts* file.

OPTIONAL PARAMETERS
-------------------

state
    If state is ``present``, make *object_id* resolve to *ip*. If
    state is ``absent``, *object_id* will no longer resolve via
    */etc/hosts*, if it was previously configured with this type.
    Manually inserted entries are unaffected.

ip
    IP address, to which hostname (=\ *object_id*) must resolve. If
    state is ``present``, this parameter is mandatory, if state is
    ``absent``, this parameter is silently ignored.

EXAMPLES
--------

.. code-block:: sh

    # Now `funny' resolves to 192.168.1.76,
    __hosts funny --ip 192.168.1.76
    # and `happy' no longer resolve via /etc/hosts if it was
    # previously configured via __hosts.
    __hosts happy --state absent

SEE ALSO
--------

:strong:`hosts`\ (5)

AUTHORS
-------

Dmitry Bogatov <KAction@gnu.org>


COPYING
-------

Copyright (C) 2015,2016 Dmitry Bogatov. Free use of this software is granted
under the terms of the GNU General Public License version 3 or later
(GPLv3+).
