cdist-type__pyvenv(7)
=====================

NAME
----
cdist-type__pyvenv - Create or remove python virtual environment


DESCRIPTION
-----------
This cdist type allows you to create or remove python virtual
environment using pyvenv.
It assumes pyvenv is already installed. Concrete package depends
on concrete OS and/or OS version/distribution.
Ensure this for e.g. in your init manifest as in the following example:

.. code-block sh

    case "$__target_host" in
        localhost)
            __package python3-venv --state present
            require="__package/python3-venv" __pyvenv /home/darko/testenv --pyvenv "pyvenv-3.4" --owner darko --group darko --mode 740 --state present
            require="__pyvenv/home/darko/testenv" __package_pip docopt --pip /home/darko/testenv/bin/pip --runas darko --state present
        ;;
    esac


REQUIRED PARAMETERS
-------------------
None

OPTIONAL PARAMETERS
-------------------
state
    Either "present" or "absent", defaults to "present"

group
   Group to chgrp to

mode
   Unix permissions, suitable for chmod

owner
   User to chown to

pyvenv
   Use this specific pyvenv

venvparams
   Specific parameters to pass to pyvenv invocation


EXAMPLES
--------

.. code-block:: sh

    __pyvenv /home/services/djangoenv

    # Use specific pyvenv 
    __pyvenv /home/foo/fooenv --pyvenv /usr/local/bin/pyvenv-3.4

    # Create python virtualenv for user foo.
    __pyvenv /home/foo/fooenv --group foo --user foo

    # Create python virtualenv with specific parameters.
    __pyvenv /home/services/djangoenv --venvparams "--copies --system-site-packages"


AUTHORS
-------
Darko Poljak <darko.poljak--@--gmail.com>


COPYING
-------
Copyright \(C) 2016 Darko Poljak. Free use of this software is
granted under the terms of the GNU General Public License v3 or later (GPLv3+).

