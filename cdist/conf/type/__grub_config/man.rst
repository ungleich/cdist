cdist-type__grub_config(7)
==========================

NAME
----
cdist-type__grub_config - Manage GRUB configuration


DESCRIPTION
-----------
GRUB (GNU GRand Unified Bootloader) is a boot loader and is the
reference implementation of FSF's Multiboot Specification.


REQUIRED PARAMETERS
-------------------
None


OPTIONAL PARAMETERS
-------------------

GRUB_DEFAULT
GRUB_TIMEOUT
GRUB_DISTRIBUTOR
GRUB_CMDLINE_LINUX_DEFAULT
GRUB_CMDLINE_LINUX
GRUB_CMDLINE_NETBSD
GRUB_CMDLINE_NETBSD_DEFAULT
GRUB_CMDLINE_GNUMACH
GRUB_CMDLINE_XEN
GRUB_CMDLINE_XEN_DEFAULT
GRUB_CMDLINE_LINUX_XEN_REPLACE
GRUB_CMDLINE_LINUX_XEN_REPLACE_DEFAULT
GRUB_BADRAM
GRUB_SAVEDEFAULT
GRUB_TERMINAL
GRUB_TIMEOUT_STYLE
GRUB_GFXMODE
GRUB_DISABLE_LINUX_UUID
GRUB_DISABLE_RECOVERY
GRUB_INIT_TUNE
GRUB_DEFAULT_BUTTON
GRUB_TIMEOUT_BUTTON
GRUB_TIMEOUT_STYLE_BUTTON
GRUB_BUTTON_CMOS_ADDRESS
GRUB_TERMINAL_INPUT
GRUB_TERMINAL_OUTPUT
GRUB_SERIAL_COMMAND
GRUB_VIDEO_BACKEND
GRUB_BACKGROUND
GRUB_THEME
GRUB_GFXPAYLOAD_LINUX
GRUB_DISABLE_OS_PROBER
GRUB_OS_PROBER_SKIP_LIST
GRUB_DISABLE_SUBMENU
GRUB_ENABLE_CRYPTODISK
GRUB_PRELOAD_MODULES
GRUB_RECORDFAIL_TIMEOUT
GRUB_RECOVERY_TITLE
GRUB_HIDDEN_TIMEOUT
GRUB_HIDDEN_TIMEOUT_QUIET
GRUB_HIDDEN_TIMEOUT_BUTTON

For parameter description, see `info -f grub -n 'Simple configuration'`


DEFAULT PARAMETERS
-------------------

GRUB_DEFAULT
GRUB_TIMEOUT


EXAMPLES
--------

.. code-block:: sh

    # on the most linux systems a small default config 
    # GRUB_DISTRIBUTOR is set with help of global vars
    __grub_config object_id --GRUB_CMDLINE_LINUX_DEFAULT quiet
    
    # more explicit
    __grub_config object_id --GRUB_DEFAULT 0 --GRUB_TIMEOUT 1 / 
        --GRUB_CMDLINE_LINUX_DEFAULT quiet
        
    # ignore bad RAM pattern
    __grub_config object_id --GRUB_DEFAULT 0 --GRUB_TIMEOUT 1 /
        --GRUB_CMDLINE_LINUX_DEFAULT quiet /
        --GRUB_CMDLINE_LINUX memmap=2M\$1004

    __grub_config object_id --GRUB_DEFAULT 0 --GRUB_TIMEOUT 1 /
        --GRUB_CMDLINE_LINUX_DEFAULT quiet /
        --GRUB_BADRAM 0x01234567

    # if you don't like the naming of the new device names (PredictableNetworkInterfacesNames)
    # if you have a space then its nessecary to escape it
    __grub_config object_id --GRUB_DEFAULT 0 --GRUB_TIMEOUT 1 /
        --GRUB_CMDLINE_LINUX_DEFAULT quiet /
        --GRUB_CMDLINE_LINUX='net.ifnames=0 biosdevname=0'


SEE ALSO
--------
:strong:`cdist-type__grub_config`\ (7)
:strong:`info -f grub -n 'Simple configuration'`

AUTHORS
-------
Daniel Tschada <mail--@--moep.name>


COPYING
-------
Copyright \(C) 2017 Daniel Tschada. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
