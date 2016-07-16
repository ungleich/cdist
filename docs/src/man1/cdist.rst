cdist(1)
========

NAME
----
cdist - Usable Configuration Management


SYNOPSIS
--------

::

    cdist [-h] [-d] [-v] [-V] {banner,config,betainventory,shell} ...

    cdist banner [-h] [-d] [-v]

    cdist config [-h] [-d] [-v] [-I INVENTORY_DIR] [-c CONF_DIR]
                 [-f HOSTFILE] [-i MANIFEST] [-n] [-o OUT_PATH] [-p] [-s]
                 [--remote-copy REMOTE_COPY] [--remote-exec REMOTE_EXEC]
                 [-t] [-a]
                 [host [host ...]]

    cdist betainventory list [-h] [-d] [-v] [-I INVENTORY_DIR] [-H] [-a] [-t]
                 [-f HOSTFILE]
                 [host [host ...]]

    cdist betainventory add-host [-h] [-d] [-v] [-I INVENTORY_DIR]
                 [-f HOSTFILE]
                 [host [host ...]]

    cdist betainventory del-host [-h] [-d] [-v] [-I INVENTORY_DIR] [-a]
                 [-f HOSTFILE]
                 [host [host ...]]

    cdist betainventory add-tag [-h] [-d] [-v] [-I INVENTORY_DIR] [-f HOSTFILE]
                 [-t TAGLIST] [-T TAGFILE]
                 [host [host ...]]

    cdist betainventory del-tag [-h] [-d] [-v] [-I INVENTORY_DIR] [-a]
                 [-f HOSTFILE] [-t TAGLIST] [-T TAGFILE]
                 [host [host ...]]

    cdist shell [-h] [-d] [-v] [-s SHELL]


DESCRIPTION
-----------
cdist is the frontend executable to the cdist configuration management.
cdist supports different subcommands as explained below.

GENERAL
-------
All commands accept the following options:

.. option:: -d, --debug

    Set log level to debug

.. option:: -h, --help

   Show the help screen

.. option:: -v, --verbose

    Set log level to info, be more verbose

.. option:: -V, --version

   Show version and exit


BANNER
------
Displays the cdist banner. Useful for printing
cdist posters - a must have for every office.


CONFIG
------
Configure one or more hosts

.. option:: -c CONF_DIR, --conf-dir CONF_DIR

    Add a configuration directory. Can be specified multiple times.
    If configuration directories contain conflicting types, explorers or
    manifests, then the last one found is used. Additionally this can also
    be configured by setting the CDIST_PATH environment variable to a colon
    delimited list of config directories. Directories given with the
    --conf-dir argument have higher precedence over those set through the
    environment variable.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to operate on from specified file
    or from stdin if '-' (each host on separate line).
    If no host or host file is specified then, by default,
    read hosts from stdin.

.. option:: -i MANIFEST, --initial-manifest MANIFEST

    Path to a cdist manifest or - to read from stdin

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Default inventory directory is
    'inventory' directory placed inside cdist distribution under 'cdist'
    directory along 'conf' directory.

.. option:: -n, --dry-run

    Do not execute code

.. option:: -p, --parallel

    Operate on multiple hosts in parallel

.. option:: -s, --sequential

    Operate on multiple hosts sequentially

.. option:: --remote-copy REMOTE_COPY

    Command to use for remote copy (should behave like scp)

.. option:: --remote-exec REMOTE_EXEC

    Command to use for remote execution (should behave like ssh)

.. option:: -t, --tag

    host is specified by tag, not hostname/address; list
    all hosts that contain any of specified tags

.. option:: -a, --all

    list hosts that have all specified tags, if -t/--tag
    is specified


INVENTORY
---------
Manage inventory database.


INVENTORY LIST
--------------
List inventory database.

.. option::  host

    host(s) to list

.. option:: -h, --help

    show this help message and exit

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Default inventory directory is
    'inventory' directory placed inside cdist distribution under 'cdist'
    directory along 'conf' directory.

.. option:: -H, --host-only

    Suppress tags listing

.. option:: -a, --all

    list hosts that have all specified tags, if -t/--tag
    is specified

.. option:: -t, --tag

    host is specified by tag, not hostname/address; list
    all hosts that contain any of specified tags

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to list from specified file or
    from stdin if '-' (each host on separate line). If no
    host or host file is specified then, by default, list
    all.


INVENTORY ADD-HOST
------------------
Add host(s) to inventory database.

.. option:: host

    host(s) to add

.. option:: -h, --help

    show this help message and exit

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Default inventory directory is
    'inventory' directory placed inside cdist distribution under 'cdist'
    directory along 'conf' directory.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to add from specified file or
    from stdin if '-' (each host on separate line). If no
    host or host file is specified then, by default, read
    from stdin.


INVENTORY DEL-HOST
------------------
Delete host(s) from inventory database.

.. option:: host

    host(s) to delete

.. option:: -h, --help

    show this help message and exit

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Default inventory directory is
    'inventory' directory placed inside cdist distribution under 'cdist'
    directory along 'conf' directory.

.. option:: -a, --all

    Delete all hosts

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to delete from specified file or
    from stdin if '-' (each host on separate line). If no
    host or host file is specified then, by default, read
    from stdin.


INVENTORY ADD-TAG
-----------------
Add tag(s) to inventory database.

.. option:: host

    list of host(s) for which tags are added

.. option:: -h, --help

    show this help message and exit

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Default inventory directory is
    'inventory' directory placed inside cdist distribution under 'cdist'
    directory along 'conf' directory.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to add tags from specified file
    or from stdin if '-' (each host on separate line). If
    no host or host file is specified then, by default,
    read from stdin. If no tags/tagfile nor hosts/hostfile
    are specified then tags are read from stdin and are
    added to all hosts.

.. option:: -t TAGLIST, --taglist TAGLIST

    Tag list to be added for specified host(s), comma
    separated values

.. option:: -T TAGFILE, --tag-file TAGFILE

    Read additional tags to add from specified file or
    from stdin if '-' (each tag on separate line). If no
    tag or tag file is specified then, by default, read
    from stdin. If no tags/tagfile nor hosts/hostfile are
    specified then tags are read from stdin and are added
    to all hosts.


INVENTORY DEL-TAG
-----------------
Delete tag(s) from inventory database.

.. option:: host

    list of host(s) for which tags are deleted

.. option:: -h, --help

    show this help message and exit

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Default inventory directory is
    'inventory' directory placed inside cdist distribution under 'cdist'
    directory along 'conf' directory.

.. option:: -a, --all

    Delete all tags for specified host(s)

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to delete tags for from
    specified file or from stdin if '-' (each host on
    separate line). If no host or host file is specified
    then, by default, read from stdin. If no tags/tagfile
    nor hosts/hostfile are specified then tags are read
    from stdin and are deleted from all hosts.

.. option:: -t TAGLIST, --taglist TAGLIST

    Tag list to be deleted for specified host(s), comma
    separated values

.. option:: -T TAGFILE, --tag-file TAGFILE

    Read additional tags from specified file or from stdin
    if '-' (each tag on separate line). If no tag or tag
    file is specified then, by default, read from stdin.
    If no tags/tagfile nor hosts/hostfile are specified
    then tags are read from stdin and are added to all
    hosts.


SHELL
-----
This command allows you to spawn a shell that enables access
to the types as commands. It can be thought as an
"interactive manifest" environment. See below for example
usage. Its primary use is for debugging type parameters.

.. option:: -s/--shell

    Select shell to use, defaults to current shell


EXAMPLES
--------

.. code-block:: sh

    # Configure ikq05.ethz.ch with debug enabled
    % cdist config -d ikq05.ethz.ch

    # Configure hosts in parallel and use a different configuration directory
    % cdist config -c ~/p/cdist-nutzung \
        -p ikq02.ethz.ch ikq03.ethz.ch ikq04.ethz.ch

    # Use custom remote exec / copy commands
    % cdist config --remote-exec /path/to/my/remote/exec \
        --remote-copy /path/to/my/remote/copy \
        -p ikq02.ethz.ch ikq03.ethz.ch ikq04.ethz.ch

    # Configure hosts read from file loadbalancers
    % cdist config -f loadbalancers

    # Display banner
    cdist banner

    # Show help
    % cdist --help

    # Show Version
    % cdist --version

    # Enter a shell that has access to emulated types
    % cdist shell
    % __git
    usage: __git --source SOURCE [--state STATE] [--branch BRANCH]
                 [--group GROUP] [--owner OWNER] [--mode MODE] object_id

    # List inventory content
    % cdist betainventory list

    # List inventory for specified host localhost
    % cdist betainventory list localhost

    # List inventory for specified tag loadbalancer
    % cdist betainventory list -t loadbalancer

    # Add hosts to inventory
    % cdist betainventory add-host web1 web2 web3

    # Delete hosts from file old-hosts from inventory
    % cdist betainventory del-host -f old-hosts

    # Add tags to specifed hosts
    % cdist betainventory add-tag -t europe,croatia,web,static web1 web2

    # Add tag to all hosts in inventory
    % cdist betainventory add-tag -t vm

    # Delete all tags from specified host
    % cdist betainventory del-tag -a localhost

    # Delete tags read from stdin from hosts specified by file hosts
    % cdist betainventory del-tag -T - -f hosts

    # Configure hosts from inventory with any of specified tags
    % cdist config -t web dynamic

    # Configure hosts from inventory with all specified tags
    % cdist config -t -a web dynamic


ENVIRONMENT
-----------
TMPDIR, TEMP, TMP
    Setup the base directory for the temporary directory.
    See http://docs.python.org/py3k/library/tempfile.html for
    more information. This is rather useful, if the standard
    directory used does not allow executables.

CDIST_LOCAL_SHELL
    Selects shell for local script execution, defaults to /bin/sh

CDIST_REMOTE_SHELL
    Selects shell for remote scirpt execution, defaults to /bin/sh

CDIST_REMOTE_EXEC
    Use this command for remote execution (should behave like ssh)

CDIST_REMOTE_COPY
    Use this command for remote copy (should behave like scp)

EXIT STATUS
-----------
The following exit values shall be returned:

0
    Successful completion
1
    One or more host configurations failed


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>

COPYING
-------
Copyright \(C) 2011-2013 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
