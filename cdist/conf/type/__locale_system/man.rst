cdist-type__locale_system(7)
============================

NAME
----
cdit-type__locale_system - Set system-wide locale


DESCRIPTION
-----------
This cdist type allows you to modify system-wide locale.


OPTIONAL PARAMETERS
-------------------
locale
   Any valid locale, defaults to en_US.UTF-8


EXAMPLES
--------

.. code-block:: sh

    # Set system locale to en_US.UTF-8
    __locale_system 

    # Same as above, but more explicit
    __locale_system --locale en_US.UTF-8


SEE ALSO
--------
:strong:`locale`\ (1), :strong:`localedef`\ (1)


AUTHORS
-------
Carlos Ortigoza <carlos.ortigoza--@--ungleich.ch>


COPYING
-------
Copyright \(C) 2016 Carlos Ortigoza. Free use of this software is
granted under the terms of the GNU General Public License v3 or later (GPLv3+).
