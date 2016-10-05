cdist-type__pacman_conf(7)
==========================

NAME
----
cdist-type__pacman_conf - Manage pacman configuration


DESCRIPTION
-----------
The type allows you to configure options section, add or delete repositories and manage mirrorlists


REQUIRED PARAMETERS
-------------------
section
    'options' for configure options section

    Otherwise it specifies a repository or a plain file

key
    Specifies the key which will be set

    If section = 'options' or file is not set the key will
    be checked against available keys from pacman.conf

value
    Specifies the value which will be set against the key


OPTIONAL PARAMETERS
-------------------
state
    'present' or 'absent', defaults to 'present'

file
    Specifies the filename.

    The managed file will be named like 'plain_file_filename'

    If supplied the key will not be checked.


EXAMPLES
--------

.. code-block:: sh

    # Manage options section in pacman.conf
    __pacman_conf options_Architecture --section options --key Architecture --value auto

    # Add new repository
    __pacman_conf localrepo_Server --section localrepo --key Server --value "file:///var/cache/pacman/pkg"

    # Add mirror to a mirrorlist
    __pacman_conf customlist_Server --file customlist --section customlist --key Server\
        --value "file:///var/cache/pacman/pkg"


SEE ALSO
--------
:strong:`grep`\ (1)


AUTHORS
-------
Dominique Roux <dominique.roux4@gmail.com>


COPYING
-------
Copyright \(C) 2015 Dominique Roux. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
