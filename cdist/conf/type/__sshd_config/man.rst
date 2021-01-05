cdist-type__sshd_config(7)
==========================

NAME
----
cdist-type__sshd_config - Manage options in sshd_config


DESCRIPTION
-----------
This space intentionally left blank.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
file
    The path to the sshd_config file to edit.
    Defaults to ``/etc/ssh/sshd_config``.
match
    Restrict this option to apply only for certain connections.
    Allowed values are what would be allowed to be written after a ``Match``
    keyword in ``sshd_config``, e.g. ``--match 'User anoncvs'``.

    Can be used multiple times. All of the values are ANDed together.
option
    The name of the option to manipulate. Defaults to ``__object_id``.
state
    Can be:

    - ``present``: ensure a matching config line is present (or the default
      value).
    - ``absent``: ensure no matching config line is present.
value
    The option's value to be assigned to the option (if ``--state present``) or
    removed (if ``--state absent``).

    This option is required if ``--state present``. If not specified and
    ``--state absent``, all values for the given option are removed.


BOOLEAN PARAMETERS
------------------
None.


EXAMPLES
--------

.. code-block:: sh

    # Disallow root logins with password
    __sshd_config PermitRootLogin --value without-password

    # Disallow password-based authentication
    __sshd_config PasswordAuthentication --value no

    # Accept the EDITOR environment variable
    __sshd_config AcceptEnv:EDITOR --option AcceptEnv --value EDITOR

    # Force command for connections as git user
    __sshd_config git@ForceCommand --match 'User git' --option ForceCommand \
        --value 'cd ~git && exec git-shell ${SSH_ORIGINAL_COMMAND:+-c "${SSH_ORIGINAL_COMMAND}"}'


SEE ALSO
--------
:strong:`sshd_config`\ (5)


BUGS
----
- This type assumes a nicely formatted config file,
  i.e. no config options spanning multiple lines.
- ``Include`` directives are ignored.
- Config options are not added/removed to/from the config file if their value is
  the default value.
- | The explorer will incorrectly report ``absent`` if OpenSSH internally
    transforms one value to another (e.g. ``permitrootlogin prohibit-password``
    is transformed to ``permitrootlogin without-password``).
  | Workaround: Use the value that OpenSSH uses internally.


AUTHORS
-------
Dennis Camera <dennis.camera--@--ssrq-sds-fds.ch>


COPYING
-------
Copyright \(C) 2020 Dennis Camera. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
