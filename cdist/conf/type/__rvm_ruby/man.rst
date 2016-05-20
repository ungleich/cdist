cdist-type__rvm_ruby(7)
=======================
Manage ruby installations through rvm

Evax Software <contact@evax.fr>


DESCRIPTION
-----------
RVM is the Ruby enVironment Manager for the Ruby programming language.


REQUIRED PARAMETERS
-------------------
user
    The remote user account to use
state
    Either "present" or "absent", defaults to "present".


BOOLEAN PARAMETERS
------------------
default
    Set the given version as default


EXAMPLES
--------

.. code-block:: sh

    # Install ruby 1.9.3 through rvm for user thelonious
    __rvm_ruby ruby-1.9.3-p0 --user thelonious --state present

    # Install ruby 1.9.3 through rvm for user ornette and make it the default
    __rvm_ruby ruby-1.9.3-p0 --user ornette --state present --default

    # Remove ruby 1.9.3 for user john
    __rvm_ruby ruby-1.9.3-p0 --user john --state absent


SEE ALSO
--------
- `cdist-type(7) <cdist-type.html>`_
- `cdist-type__rvm(7) <cdist-type__rvm.html>`_
- `cdist-type__rvm_gemset(7) <cdist-type__rvm_gemset.html>`_
- `cdist-type__rvm_gem(7) <cdist-type__rvm_gem.html>`_


COPYING
-------
Copyright \(C) 2012 Evax Software. Free use of this software is granted under
the terms of the GNU General Public License version 3 (GPLv3).
