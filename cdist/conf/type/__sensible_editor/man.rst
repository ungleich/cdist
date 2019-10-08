cdist-type__sensible_editor(7)
==============================

NAME
----
cdist-type__sensible_editor - Select the sensible-editor


DESCRIPTION
-----------
This cdist type allows you to select the :strong:`sensible-editor` for
a given user.


REQUIRED PARAMETERS
-------------------
editor
    Name or path of the editor to be selected.
    On systems other than Debian derivatives an absolute path is required.


OPTIONAL PARAMETERS
-------------------
state
    Either "present" or "absent". Defaults to "present".


EXAMPLES
--------

.. code-block:: sh

    __sensible_editor root --editor /bin/ed  # ed(1) is the standard
    __sensible_editor noob --editor nano


LIMITATIONS
-----------
This type only works on operating systems on which the sensible-utils package
is available.

Hint: On RedHat-based systems setting up the EPEL repo might be necessary.


SEE ALSO
--------
:strong:`select-editor`\ (1), :strong:`sensible-editor`\ (1).


AUTHOR
-------
Dennis Camera <dennis.camera--@--ssrq-sds-fds.ch>


COPYING
-------
Copyright \(C) 2019 Dennis Camera.
You can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.
