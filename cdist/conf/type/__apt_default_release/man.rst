cdist-type__apt_default_release(7)
==================================

NAME
----
cdist-type__apt_default_release - Configure the default release for apt


DESCRIPTION
-----------
Configure the default release for apt, using the APT::Default-Release
configuration value.

REQUIRED PARAMETERS
-------------------
release
   The value to set APT::Default-Release to.

   This can contain release name, codename or release version. Examples:
   'stable', 'testing', 'unstable', 'stretch', 'buster', '4.0', '5.0*'.


OPTIONAL PARAMETERS
-------------------
None.


EXAMPLES
--------

.. code-block:: sh

    __apt_default_release --release stretch


AUTHORS
-------
Matthijs Kooijman <matthijs--@--stdin.nl>


COPYING
-------
Copyright \(C) 2017 Matthijs Kooijman. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
