cdist-type__ssh_authorized_key(7)
=================================

NAME
----
cdist-type__ssh_authorized_key - Manage a single ssh authorized key entry


DESCRIPTION
-----------
Manage a single authorized key entry in an authorized_key file.
This type was created to be used by the __ssh_authorized_keys type.


REQUIRED PARAMETERS
-------------------
file
   The authorized_keys file where the given key should be managed.

key
   The ssh key which shall be managed in this authorized_keys file.
   Must be a string containing the ssh keytype, base 64 encoded key and
   optional trailing comment which shall be added to the given
   authorized_keys file.


OPTIONAL PARAMETERS
-------------------
comment
   Use this comment instead of the one which may be trailing in the key.

option
   An option to set for this authorized_key entry.
   Can be specified multiple times.
   See sshd(8) for available options.

state
   If the managed key should be 'present' or 'absent', defaults to 'present'.


MESSAGES
--------
added to `file` (`entry`)
   The key `entry` (with optional comment) was added to `file`.

removed from `file` (`entry`)
   The key `entry` (with optional comment) was removed from `file`.


EXAMPLES
--------

.. code-block:: sh

    __ssh_authorized_key some-id \
       --file "/home/user/.ssh/autorized_keys" \
       --key "$(cat ~/.ssh/id_rsa.pub)"

    __ssh_authorized_key some-id \
       --file "/home/user/.ssh/autorized_keys" \
       --key "$(cat ~/.ssh/id_rsa.pub)" \
       --option 'command="/path/to/script"' \
       --option 'environment="FOO=bar"' \
       --comment 'one to rule them all'


SEE ALSO
--------
:strong:`cdist-type__ssh_authorized_keys`\ (7), :strong:`sshd`\ (8)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2014 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
