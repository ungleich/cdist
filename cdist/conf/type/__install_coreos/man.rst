cdist-type__install_coreos(7)
=============================

NAME
----

cdist-type__install_coreos - Install CoreOS

DESCRIPTION
-----------

This type installs CoreOS to a given device using coreos-install_, which is
present in CoreOS ISO by default.

.. _coreos-install: https://raw.githubusercontent.com/coreos/init/master/bin/coreos-install

REQUIRED PARAMETERS
-------------------

device
    A device CoreOS will be installed to.

OPTIONAL PARAMETERS
-------------------

ignition
    Path to ignition config.

EXAMPLES
--------

.. code-block:: sh

    __install_coreos \
        --device /dev/sda \
        --ignition ignition.json


AUTHORS
-------

Ľubomír Kučera <lubomir.kucera.jr at gmail.com>

COPYING
-------

Copyright \(C) 2018 Ľubomír Kučera. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
