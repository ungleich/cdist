cdist-type__config_file(7)
==========================

NAME
----
cdist-type__config_file - _Manages config files


DESCRIPTION
-----------
Deploy config files using the file type.
Run the given code if the files changes.


REQUIRED PARAMETERS
-------------------
None.


OPTIONAL PARAMETERS
-------------------
group
   see cdist-type__file
mode
   see cdist-type__file
onchange
   the code to run if the file changes
owner
   see cdist-type__file
source
   Path to the config file.
   If source is '-' (dash), take what was written to stdin as the config file content.
state
   see cdist-type__file


EXAMPLES
--------

.. code-block:: sh

    __config_file /etc/consul/conf.d/watch_foo.json \
       --owner root --group consul --mode 640 \
       --source "$__type/files/watch_foo.json" \
       --state present \
       --onchange 'service consul status >/dev/null && service consul reload || true'


SEE ALSO
--------
:strong:`cdist-type__file`\ (7)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2015 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
