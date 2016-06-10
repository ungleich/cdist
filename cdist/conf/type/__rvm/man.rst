cdist-type__rvm(7)
==================
Install rvm for a given user

Evax Software <contact@evax.fr>


DESCRIPTION
-----------
RVM is the Ruby enVironment Manager for the Ruby programming language.


REQUIRED PARAMETERS
-------------------
state
    Either "present" or "absent", defaults to "present".


EXAMPLES
--------

.. code-block:: sh

    # Install rvm for user billie
    __rvm billie --state present

    # Remove rvm
    __rvm billie --state absent


SEE ALSO
--------
- `cdist-type(7) <cdist-type.html>`_
- `cdist-type__rvm_ruby(7) <cdist-type__rvm_ruby.html>`_
- `cdist-type__rvm_gemset(7) <cdist-type__rvm_gemset.html>`_
- `cdist-type__rvm_gem(7) <cdist-type__rvm_gem.html>`_


COPYING
-------
Copyright \(C) 2012 Evax Software. Free use of this software is granted under
the terms of the GNU General Public License version 3 (GPLv3).
