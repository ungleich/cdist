cdist-type__ssh_authorized_keys(7)
==================================

NAME
----
cdist-type__ssh_authorized_keys - Manage ssh authorized_keys files


DESCRIPTION
-----------
Adds or removes ssh keys from a authorized_keys file.

This type uses the __ssh_dot_ssh type to manage the directory containing
the authorized_keys file. You can disable this feature with the --noparent
boolean parameter.

The existence, ownership and permissions of the authorized_keys file itself are
also managed. This can be disabled with the --nofile boolean parameter. It is
then left to the user to ensure that the file exists and that ownership and
permissions work with ssh.


REQUIRED PARAMETERS
-------------------
key
   the ssh key which shall be added to this authorized_keys file.
   Must be a string and can be specified multiple times.


OPTIONAL PARAMETERS
-------------------
comment
   explicit comment instead of the one which may be trailing the given key

file
   an alternative destination file, defaults to ~$owner/.ssh/authorized_keys

option
   an option to set for all created authorized_key entries.
   Can be specified multiple times.
   See sshd(8) for available options.

owner
   the user owning the authorized_keys file, defaults to object_id.

state
   if the given keys should be 'present' or 'absent', defaults to 'present'.


BOOLEAN PARAMETERS
------------------
noparent
   don't create or change ownership and permissions of the directory containing
   the authorized_keys file

nofile
   don't manage existence, ownership and permissions of the the authorized_keys
   file


EXAMPLES
--------

.. code-block:: sh

    # add your ssh key to remote root's authorized_keys file
    __ssh_authorized_keys root \
       --key "$(cat ~/.ssh/id_rsa.pub)"

    # allow key to login as user-name
    __ssh_authorized_keys user-name \
       --key "ssh-rsa AXYZAAB3NzaC1yc2..."

    # allow key to login as user-name with options and expicit comment
    __ssh_authorized_keys user-name \
       --key "ssh-rsa AXYZAAB3NzaC1yc2..." \
       --option no-agent-forwarding \
       --option 'from="*.example.com"' \
       --comment 'backup server'

    # same as above, but with explicit owner and two keys
    # note that the options are set for all given keys
    __ssh_authorized_keys some-fancy-id \
       --owner user-name \
       --key "ssh-rsa AXYZAAB3NzaC1yc2..." \
       --key "ssh-rsa AZXYAAB3NzaC1yc2..." \
       --option no-agent-forwarding \
       --option 'from="*.example.com"' \
       --comment 'backup server'

    # authorized_keys file in non standard location
    __ssh_authorized_keys some-fancy-id \
       --file /etc/ssh/keys/user-name/authorized_keys \
       --owner user-name \
       --key "ssh-rsa AXYZAAB3NzaC1yc2..."

    # same as above, but directory and authorized_keys file is created elswhere
    __ssh_authorized_keys some-fancy-id \
       --file /etc/ssh/keys/user-name/authorized_keys \
       --owner user-name \
       --noparent \
       --nofile \
       --key "ssh-rsa AXYZAAB3NzaC1yc2..."


SEE ALSO
--------
:strong:`sshd`\ (8)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2012-2014 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
