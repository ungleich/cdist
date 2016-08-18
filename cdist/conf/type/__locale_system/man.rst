cdist-type__locale_system(7)
============================

NAME
----
cdist-type__locale_system - Set system-wide locale


DESCRIPTION
-----------
This cdist type allows you to modify system-wide locale.
The name of the locale category is given as the object id
(usually you are probably interested in using LANG).


OPTIONAL PARAMETERS
-------------------

state
    present or absent, defaults to present.
    If present, sets the locale category to the given value.
    If absent, removes the locale category from the system file.

value
    The value for the locale category.
    Defaults to en_US.UTF-8.


EXAMPLES
--------

.. code-block:: sh

    # Set LANG to en_US.UTF-8
    __locale_system LANG

    # Same as above, but more explicit
    __locale_system LANG --value en_US.UTF-8

    # Set category LC_MESSAGES to de_CH.UTF-8
    __locale_system LC_MESSAGES --value de_CH.UTF-8

    # Remove setting for LC_ALL
    __locale_system LC_ALL --state absent



SEE ALSO
--------
:strong:`locale`\ (1), :strong:`localedef`\ (1), :strong:`cdist-type__locale`\ (7)


AUTHORS
-------
| Steven Armstrong <steven-cdist--@--armstrong.cc>
| Carlos Ortigoza <carlos.ortigoza--@--ungleich.ch>
| Nico Schottelius <nico.schottelius--@--ungleich.ch>


COPYING
-------
Copyright \(C) 2016 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License version 3 or
later (GPLv3+).
