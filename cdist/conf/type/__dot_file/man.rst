cdist-type__dot_file(7)
========================

NAME
----

cdist-type__dot_file - install file under user's home directory

DESCRIPTION
-----------

This type installs a file (=\ *__object_id*) under user's home directory,
providing a way to install per-user configuration files. File owner
and group is deduced from user, for who file is installed.

Unlike regular __file type, you do not need make any assumptions,
where user's home directory is.

REQUIRED PARAMETERS
-------------------

user
    User, for who file is installed

OPTIONAL PARAMETERS
-------------------

mode
    forwarded to :strong:`__file` type

state
    forwarded to :strong:`__file` type

source
    forwarded to :strong:`__file` type

MESSAGES
--------

This type inherits all messages from :strong:`file` type, and do not add
any new.

EXAMPLES
--------

.. code-block:: sh

    # Install .forward file for user 'alice'. Since state is 'present',
    # user is not meant to edit this file, all changes will be overridden.
    # It is good idea to put warning about it in file itself.
    __dot_file .forward --user alice --source "$__files/forward"

    # Install .muttrc for user 'bob', if not already present. User can safely
    # edit it, his changes will not be overwritten.
    __dot_file .muttrc --user bob --source "$__files/recommended_mutt_config" --state exists


    # Install default xmonad config for user 'eve'. Parent directory is created automatically.
    __dot_file .xmonad/xmonad.hs --user eve --state exists --source "$__files/xmonad.hs"

SEE ALSO
--------

**cdist-type__file**\ (7)

COPYING
-------

Copyright (C) 2015 Dmitry Bogatov. Free use of this software is granted
under the terms of the GNU General Public License version 3 or later
(GPLv3+).
