cdist-type__select_editor(7)
============================

NAME
----
cdist-type__select_editor - Select the sensible-editor


DESCRIPTION
-----------
This cdist type allows you to select the sensible-editor on Debian-based systems
for a given user.


REQUIRED PARAMETERS
-------------------
editor
    Name or path of the editor to be selected.


OPTIONAL PARAMETERS
-------------------
state
    either "present" or "absent". Defaults to "present".


EXAMPLES
--------

.. code-block:: sh

    __select_editor root --editor /bin/ed  # ed(1) is the standard
    __select_editor noob --editor nano


SEE ALSO
--------
none


AUTHOR
-------
Dennis Camera <dennis.camera--@--ssrq-sds-fds.ch>


COPYING
-------
Copyright \(C) 2019 Dennis Camera.
You can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.
