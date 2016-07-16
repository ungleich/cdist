cdist-type__locale(7)
=====================

NAME
----
cdit-type__locale - Configure locales


DESCRIPTION
-----------
This cdist type allows you to setup locales.


OPTIONAL PARAMETERS
-------------------
state
   'present' or 'absent', defaults to present


EXAMPLES
--------

.. code-block:: sh

    # Add locale de_CH.UTF-8
    __locale de_CH.UTF-8

    # Same as above, but more explicit
    __locale de_CH.UTF-8 --state present

    # Remove colourful British English
    __locale en_GB.UTF-8 --state absent


SEE ALSO
--------
:strong:`locale`\ (1), :strong:`localedef`\ (1)


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2013-2014 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
