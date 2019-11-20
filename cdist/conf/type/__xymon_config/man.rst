cdist-type__xymon_config(7)
===========================

NAME
----
cdist-type__xymon_config - Deploy a Xymon configuration-directory


DESCRIPTION
-----------
This cdist type deploys a full Xymon configuration directory from the files-dir
to the host.  This type requires an installed Xymon server, e.g. deployed by
`__xymon_server`.

WARNING: This type _replaces_ the `/etc/xymon/`-directory! The previous
contents is replaced/deleted!


REQUIRED PARAMETERS
-------------------
confdir
   The directory in `./files/` that contains the `/etc/xymon/`-content to be
   deployed.


OPTIONAL PARAMETERS
-------------------
owner
   passed as-is as `--owner` to `__rsync`

group
   passed as-is as `--group` to `__rsync`


OPTIONAL MULTIPLE PARAMETERS
----------------------------
rsync-opts
   identical to __rsync type, only `--`-options are supported


REQUIRED FILES
--------------
The directory specified by `confdir` has to contain a valid xymon-configuration
(`/etc/xymon/`) _plus_ the `ext/`-directory that normally resides in
`/usr/lib/xymon/server/`.


EXAMPLES
--------

.. code-block:: sh

    __xymon_config --confdir=xymon.example.com
    # this will replace /etc/xymon/ on the target host with
    # the contents from __xymon_config/files/xymon.example.com/

    ## the same but set ownership to `xymon:xymon` and exclude
    ## the `netrc`-file:
    __xymon_config --confdir=xymon.example.com \
       --owner xymon --group xymon \
       --rsync-opts "exclude=netrc"


SEE ALSO
--------
:strong:`cdist__xymon_server`\ (7), :strong:`cdist__rsync`\ (7), :strong:`xymon`\ (7)

AUTHORS
-------
Thomas Eckert <tom--@--it-eckert.de>


COPYING
-------
Copyright \(C) 2018-2019 Thomas Eckert. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
