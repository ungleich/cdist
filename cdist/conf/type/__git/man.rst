cdist-type__git(7)
==================

NAME
----
cdist-type__git -  Get and or keep git repositories up-to-date


DESCRIPTION
-----------
This cdist type allows you to clone git repositories


REQUIRED PARAMETERS
-------------------
source
    Specifies the git remote to clone from


OPTIONAL PARAMETERS
-------------------
state
    Either "present" or "absent", defaults to "present"

branch
    Create this branch by checking out the remote branch of this name
    Default branch is "master"

group
   Group to chgrp to.

mode
   Unix permissions, suitable for chmod.

owner
   User to chown to.


EXAMPLES
--------

.. code-block:: sh

    __git /home/services/dokuwiki --source git://github.com/splitbrain/dokuwiki.git

    # Checkout cdist, stay on branch 2.1
    __git /home/nico/cdist --source git://github.com/ungleich/cdist.git --branch 2.1


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>


COPYING
-------
Copyright \(C) 2012 Nico Schottelius. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
