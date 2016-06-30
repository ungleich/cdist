cdist-type__apt_ppa(7)
======================

NAME
----
cdist-type__apt_ppa - Manage ppa repositories


DESCRIPTION
-----------
This cdist type allows manage ubuntu ppa repositories.


REQUIRED PARAMETERS
-------------------
state
   The state the ppa should be in, either 'present' or 'absent'.
   Defaults to 'present'


OPTIONAL PARAMETERS
-------------------
None.


EXAMPLES
--------

.. code-block:: sh

    # Enable a ppa repository
    __apt_ppa ppa:sans-intern/missing-bits
    # same as
    __apt_ppa ppa:sans-intern/missing-bits --state present

    # Disable a ppa repository
    __apt_ppa ppa:sans-intern/missing-bits --state absent


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011-2014 Steven Armstrong. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
