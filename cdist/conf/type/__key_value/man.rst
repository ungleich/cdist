cdist-type__key_value(7)
========================

NAME
----
cdist-type__key_value - Change property values in files


DESCRIPTION
-----------
This cdist type allows you to change values in a key value based config
file.


REQUIRED PARAMETERS
-------------------
file
   The file to operate on.
delimiter
   The delimiter which separates the key from the value.


OPTIONAL PARAMETERS
-------------------
state
    present or absent, defaults to present. If present, sets the key to value,
    if absent, removes the key from the file.
key
    The key to change. Defaults to object_id.
value
    The value for the key. Optional if state=absent, required otherwise.
comment
    If supplied, the value will be inserted before the line with the key,
    but only if the key or value must be changed.
    You need to ensure yourself that the line is prefixed with the correct
    comment sign. (for example # or ; or wathever ..)


BOOLEAN PARAMETERS
------------------
exact_delimiter
    If supplied, treat additional whitespaces between key, delimiter and value
    as wrong value.


MESSAGES
--------
remove
    Removed existing key and value
insert
    Added key and value
change
    Changed value of existing key
create
    A new line was inserted in a new file


EXAMPLES
--------

.. code-block:: sh

    # Set the maximum system user id
    __key_value SYS_UID_MAX --file /etc/login.defs --value 666 --delimiter ' '

    # Same with fancy id
    __key_value my-fancy-id --file /etc/login.defs --key SYS_UID_MAX --value 666 \
       --delimiter ' '

    # Enable packet forwarding
    __key_value net.ipv4.ip_forward --file /etc/sysctl.conf --value 1 \
       --delimiter ' = ' --comment '# my linux kernel should act as a router'

    # Remove existing key/value
    __key_value LEGACY_KEY --file /etc/somefile --state absent --delimiter '='


MORE INFORMATION
----------------
This type try to handle as many values as possible, so it doesn't use regexes.
So you need to exactly specify the key and delimiter. Delimiter can be of any length.


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2011 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
