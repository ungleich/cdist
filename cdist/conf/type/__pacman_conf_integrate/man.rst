cdist-type__pacman_conf_integrate(7)
====================================

NAME
----
cdist-type__pacman_conf_integrate - Integrate default pacman.conf to cdist conform and vice versa


DESCRIPTION
-----------
The type allows you to convert the default pacman.conf to a cdist conform one and vice versa


REQUIRED PARAMETERS
-------------------
None.

OPTIONAL PARAMETERS
-------------------
state
    'present' or 'absent', defaults to 'present'


EXAMPLES
--------

.. code-block:: sh

    # Convert normal to cdist conform
    __pacman_conf_integrate convert

    # Convert cdist conform to normal
    __pacman_conf_integrate convert --state absent


SEE ALSO
--------
:strong:`grep`\ (1)


AUTHORS
-------
Dominique Roux <dominique.roux4@gmail.com>


COPYING
-------
Copyright \(C) 2015 Dominique Roux. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
