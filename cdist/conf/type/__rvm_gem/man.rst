cdist-type__rvm_gemset(7)
==========================

NAME
----
cdist-type__rvm_gemset - Manage Ruby gems through rvm


DESCRIPTION
-----------
RVM is the Ruby enVironment Manager for the Ruby programming language.


REQUIRED PARAMETERS
-------------------
user
    The remote user account to use
gemset
    The gemset to use
state
    Either "present" or "absent", defaults to "present".

OPTIONAL PARAMETERS
-------------------
default
    Make the selected gemset the default

EXAMPLES
--------

.. code-block:: sh

    # Install the rails gem in gemset ruby-1.9.3-p0@myset for user bill
    __rvm_gemset rails --gemset ruby-1.9.3-p0@myset --user bill --state present

    # Do the same and also make ruby-1.9.3-p0@myset the default gemset
    __rvm_gemset rails --gemset ruby-1.9.3-p0@myset --user bill \
                       --state present --default

    # Remove it
    __rvm_ruby rails --gemset ruby-1.9.3-p0@myset --user bill --state absent


SEE ALSO
--------
:strong:`cdist-type__rvm`\ (7), :strong:`cdist-type__rvm_gemset`\ (7),
:strong:`cdist-type__rvm_ruby`\ (7)


AUTHORS
-------
Evax Software <contact@evax.fr>


COPYING
-------
Copyright \(C) 2012 Evax Software. Free use of this software is granted under
the terms of the GNU General Public License version 3 (GPLv3).
