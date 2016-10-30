cdist-type__preos_debootstrap(7)
================================

NAME
----
cdist-type__preos_debootstrap - create PreOS debian or ubuntu


DESCRIPTION
-----------
Create and/or configure minimal PreOS debian or ubuntu using debootstrap
and/or create PXE boot. Currently only network bootable PreOS is supported.


OPTIONAL PARAMETERS
-------------------
arch
    Use arch architecture (default amd64).

cdist-params
    Parameters for cdist invocation when configuring bootstrapped PreOS.
    By default, '-v' is turned on.

init-manifest
    Initial manifest for cdist invocation when configuring bootstrapped PreOS.
    By default, 'init' file under type's 'files' directory is used.

mirror
    Mirror debootstrap will use.

os
    Create specifed OS as PreOS. Available values are 'debian' and 'ubuntu'.
    By default, 'debian' is used.

pxe-boot-dir
    Location for PXE files. If empty then PXE is not created.

remote-copy
    remote-copy command for cdist invocation when configuring bootstrapped PreOS.
    By default, 'remote-copy.sh' file under type's 'files' directory is used.

remote-exec
    remote-exec command for cdist invocation when configuring bootstrapped PreOS.
    By default, 'remote-exec.sh' file under type's 'files' directory is used.

suite
    Use specified suite (default is stable).

trigger-command
    Command PreOS will use to trigger cdist at cdist machine.


OPTIONAL MULTIPLE PARAMETERS
----------------------------
keyfile
    ssh key file that will be added to PreOS root ssh authorized keys.


BOOLEAN PARAMETERS
------------------
bootstrap
    If set then PreOS is bootstrapped.

configure
    If set then bootstrapped PreOS is configured by invoking cdist config.

rm-bootstrap-dir
    Remove bootstrap directory when finished. Usefull to clean when PXE
    is used and bootstrap directory is no longer needed.


EXAMPLES
--------

.. code-block:: sh

    # Bootstrap default stable debian PreOS in /usr/preos
    # and configure it with using specified ssh key for authoried keys and
    # with specified trigger command
    # and create PXE in /pxe.
    __preos_debootstrap /usr/preos --bootstrap --configure --pxe-boot-dir /pxe \
        --keyfile ~/.ssh/id_rsa.pub --trigger-command "/usr/bin/curl 192.168.111.5"

    # Create default stable ubuntu PreOS.
    __preos_debootstrap /usr/preos --os ubuntu --bootstrap --configure \
        --pxe-boot-dir /pxe --keyfile ~/.ssh/id_rsa.pub \
        --trigger-command "/usr/bin/curl 192.168.111.5"


SEE ALSO
--------
:strong:`debootstrap`\ (8), :strong:`pxeboot`\ (8)


AUTHORS
-------
Darko Poljak <darko.poljak--@--ungleich.ch>


COPYING
-------
Copyright \(C) 2016 Darko Poljak. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
