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

	It is permissible to omit this parameter if --state is absent.


OPTIONAL PARAMETERS
-------------------
state
    'present', 'absent', or 'exists'. Defaults to 'present', where:

    present
        the sensible-editor is exactly what is specified in --editor.
    absent
        no sensible-editor configuration is present.
    exists
        the sensible-editor will be set to what is specified in --editor,
        unless there already is a configuration on the target system.


EXAMPLES
--------

.. code-block:: sh

    __sensible_editor root --editor /bin/ed  # ed(1) is the standard
    __sensible_editor noob --editor nano


LIMITATIONS
-----------

This type depends upon the :strong:`sensible-editor`\ (1) script which
is part of the sensible-utils package.

Therefore, the following operating systems are supported:
  * Debian 8 (jessie) or later
  * Devuan
  * Ubuntu 8.10 (intrepid) or later
  * RHEL/CentOS 7 or later (EPEL repo required)
  * Fedora 21 or later

Note: on old versions of Ubuntu the sensible-* utils are part of the
debianutils package.

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
