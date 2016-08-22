cdist(1)
========

NAME
----
cdist - Usable Configuration Management


SYNOPSIS
--------

::

    cdist [-h] [-d] [-v] [-V] {banner,config,inventory,shell} ...

    cdist banner [-h] [-d] [-v]

    cdist config [-h] [-d] [-v] [-b] [-I INVENTORY_DIR] [-c CONF_DIR]
                 [-f HOSTFILE] [-i MANIFEST] [-j [JOBS]] [-n] [-o OUT_PATH]
                 [-p] [-s] [--remote-copy REMOTE_COPY]
                 [--remote-exec REMOTE_EXEC] [-t] [-a]
                 [host [host ...]]

    cdist inventory list [-h] [-d] [-v] [-b] [-I INVENTORY_DIR] [-a]
                         [-f HOSTFILE] [-H] [-t]
                         [host [host ...]]

    cdist inventory add-host [-h] [-d] [-v] [-b] [-I INVENTORY_DIR]
                             [-f HOSTFILE]
                             [host [host ...]]

    cdist inventory del-host [-h] [-d] [-v] [-b] [-I INVENTORY_DIR] [-a]
                             [-f HOSTFILE]
                             [host [host ...]]

    cdist inventory add-tag [-h] [-d] [-v] [-b] [-I INVENTORY_DIR]
                            [-f HOSTFILE] [-T TAGFILE] [-t TAGLIST]
                            [host [host ...]]

    cdist inventory del-tag [-h] [-d] [-v] [-b] [-I INVENTORY_DIR] [-a]
                            [-f HOSTFILE] [-T TAGFILE] [-t TAGLIST]
                            [host [host ...]]

    cdist shell [-h] [-d] [-v] [-s SHELL]


DESCRIPTION
-----------
cdist is the frontend executable to the cdist configuration management.
It supports different subcommands as explained below.

It is written in Python so it requires :strong:`python`\ (1) to be installed.
It requires a minimal Python version 3.2.

GENERAL
-------
All commands accept the following options:

.. option:: -h, --help

    Show the help screen

.. option:: -d, --debug

    Set log level to debug

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
Configure one or more hosts.

.. option:: -a, --all

    list hosts that have all specified tags, if -t/--tag
    is specified

.. option:: -b, --enable-beta

    Enable beta functionalities. Beta functionalities
    include inventory command with all sub-commands and
    all options; config sub-command options: -j/--jobs,
    -t/--tag, -a/--all.

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
    read hosts from stdin. For the file format see below.

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Default inventory directory is
    'inventory' directory placed inside cdist distribution under 'cdist'
    directory along 'conf' directory.

.. option:: -i MANIFEST, --initial-manifest MANIFEST

    Path to a cdist manifest or - to read from stdin

.. option:: -j [JOBS], --jobs [JOBS]

    Specify the maximum number of parallel jobs; currently only
    global explorers are supported (currently in beta)

.. option:: -n, --dry-run

    Do not execute code

.. option:: -o OUT_PATH, --out-dir OUT_PATH

    Directory to save cdist output in

.. option:: -p, --parallel

    Operate on multiple hosts in parallel

.. option:: -s, --sequential

    Operate on multiple hosts sequentially (default)

.. option:: --remote-copy REMOTE_COPY

    Command to use for remote copy (should behave like scp)

.. option:: --remote-exec REMOTE_EXEC

    Command to use for remote execution (should behave like ssh)

.. option:: -t, --tag

    host is specified by tag, not hostname/address; list
    all hosts that contain any of specified tags

HOSTFILE FORMAT
~~~~~~~~~~~~~~~
HOSTFILE contains hosts per line. 
All characters after and including '#' until the end of line is a comment.
In a line, all leading and trailing whitespace characters are ignored.
Empty lines are ignored/skipped.

Hostfile line is processed like the following. First, all comments are
removed. Then all leading and trailing whitespace characters are stripped.
If such a line results in empty line it is ignored/skipped. Otherwise,
host string is used.


INVENTORY
---------
Manage inventory database.
Currently in beta with all sub-commands.


INVENTORY LIST
--------------
List inventory database.

.. option::  host

    host(s) to list

.. option:: -a, --all

    list hosts that have all specified tags, if -t/--tag
    is specified

.. option:: -b, --enable-beta

    Enable beta functionalities. Beta functionalities
    include inventory command with all sub-commands and
    all options; config sub-command options: -j/--jobs,
    -t/--tag, -a/--all.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to list from specified file or
    from stdin if '-' (each host on separate line). If no
    host or host file is specified then, by default, list
    all. Hostfile format is the same as config hostfile format.

.. option:: -H, --host-only

    Suppress tags listing

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Default inventory directory is
    'inventory' directory placed inside cdist distribution under 'cdist'
    directory along 'conf' directory.

.. option:: -t, --tag

    host is specified by tag, not hostname/address; list
    all hosts that contain any of specified tags


INVENTORY ADD-HOST
------------------
Add host(s) to inventory database.

.. option:: host

    host(s) to add

.. option:: -b, --enable-beta

    Enable beta functionalities. Beta functionalities
    include inventory command with all sub-commands and
    all options; config sub-command options: -j/--jobs,
    -t/--tag, -a/--all.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to add from specified file or
    from stdin if '-' (each host on separate line). If no
    host or host file is specified then, by default, read
    from stdin. Hostfile format is the same as config hostfile format.

.. option:: -h, --help

    show this help message and exit

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Default inventory directory is
    'inventory' directory placed inside cdist distribution under 'cdist'
    directory along 'conf' directory.


INVENTORY DEL-HOST
------------------
Delete host(s) from inventory database.

.. option:: host

    host(s) to delete

.. option:: -a, --all

    Delete all hosts

.. option:: -b, --enable-beta

    Enable beta functionalities. Beta functionalities
    include inventory command with all sub-commands and
    all options; config sub-command options: -j/--jobs,
    -t/--tag, -a/--all.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to delete from specified file or
    from stdin if '-' (each host on separate line). If no
    host or host file is specified then, by default, read
    from stdin. Hostfile format is the same as config hostfile format.

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Default inventory directory is
    'inventory' directory placed inside cdist distribution under 'cdist'
    directory along 'conf' directory.


INVENTORY ADD-TAG
-----------------
Add tag(s) to inventory database.

.. option:: host

    list of host(s) for which tags are added

.. option:: -b, --enable-beta

    Enable beta functionalities. Beta functionalities
    include inventory command with all sub-commands and
    all options; config sub-command options: -j/--jobs,
    -t/--tag, -a/--all.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to add tags from specified file
    or from stdin if '-' (each host on separate line). If
    no host or host file is specified then, by default,
    read from stdin. If no tags/tagfile nor hosts/hostfile
    are specified then tags are read from stdin and are
    added to all hosts. Hostfile format is the same as config hostfile format.

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Default inventory directory is
    'inventory' directory placed inside cdist distribution under 'cdist'
    directory along 'conf' directory.

.. option:: -T TAGFILE, --tag-file TAGFILE

    Read additional tags to add from specified file or
    from stdin if '-' (each tag on separate line). If no
    tag or tag file is specified then, by default, read
    from stdin. If no tags/tagfile nor hosts/hostfile are
    specified then tags are read from stdin and are added
    to all hosts. Tagfile format is the same as config hostfile format.

.. option:: -t TAGLIST, --taglist TAGLIST

    Tag list to be added for specified host(s), comma
    separated values


INVENTORY DEL-TAG
-----------------
Delete tag(s) from inventory database.

.. option:: host

    list of host(s) for which tags are deleted

.. option:: -a, --all

    Delete all tags for specified host(s)

.. option:: -b, --enable-beta

    Enable beta functionalities. Beta functionalities
    include inventory command with all sub-commands and
    all options; config sub-command options: -j/--jobs,
    -t/--tag, -a/--all.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to delete tags for from
    specified file or from stdin if '-' (each host on
    separate line). If no host or host file is specified
    then, by default, read from stdin. If no tags/tagfile
    nor hosts/hostfile are specified then tags are read
    from stdin and are deleted from all hosts. Hostfile
    format is the same as config hostfile format.

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Default inventory directory is
    'inventory' directory placed inside cdist distribution under 'cdist'
    directory along 'conf' directory.

.. option:: -T TAGFILE, --tag-file TAGFILE

    Read additional tags from specified file or from stdin
    if '-' (each tag on separate line). If no tag or tag
    file is specified then, by default, read from stdin.
    If no tags/tagfile nor hosts/hostfile are specified
    then tags are read from stdin and are added to all
    hosts. Tagfile format is the same as config hostfile format.

.. option:: -t TAGLIST, --taglist TAGLIST

    Tag list to be deleted for specified host(s), comma
    separated values


SHELL
-----
This command allows you to spawn a shell that enables access
to the types as commands. It can be thought as an
"interactive manifest" environment. See below for example
usage. Its primary use is for debugging type parameters.

.. option:: -s SHELL, --shell SHELL

    Select shell to use, defaults to current shell. Used shell should
    be POSIX compatible shell.

FILES
-----
~/.cdist
    Your personal cdist config directory. If exists it will be
    automatically used.
cdist/conf
    The distribution configuration directory. It contains official types and
    explorers. This path is relative to cdist installation directory.
cdist/inventory
    The distribution inventory directory.
    This path is relative to cdist installation directory.

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

    # Configure hosts read from file web.hosts using 16 parallel jobs
    # (beta functionality)
    % cdist config -b -j 16 -f web.hosts

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
    % cdist inventory list -b

    # List inventory for specified host localhost
    % cdist inventory list -b localhost

    # List inventory for specified tag loadbalancer
    % cdist inventory list -b -t loadbalancer

    # Add hosts to inventory
    % cdist inventory add-host -b web1 web2 web3

    # Delete hosts from file old-hosts from inventory
    % cdist inventory del-host -b -f old-hosts

    # Add tags to specifed hosts
    % cdist inventory add-tag -b -t europe,croatia,web,static web1 web2

    # Add tag to all hosts in inventory
    % cdist inventory add-tag -b -t vm

    # Delete all tags from specified host
    % cdist inventory del-tag -b -a localhost

    # Delete tags read from stdin from hosts specified by file hosts
    % cdist inventory del-tag -b -T - -f hosts

    # Configure hosts from inventory with any of specified tags
    % cdist config -b -t web dynamic

    # Configure hosts from inventory with all specified tags
    % cdist config -b -t -a web dynamic


ENVIRONMENT
-----------
TMPDIR, TEMP, TMP
    Setup the base directory for the temporary directory.
    See http://docs.python.org/py3k/library/tempfile.html for
    more information. This is rather useful, if the standard
    directory used does not allow executables.

CDIST_PATH
    Colon delimited list of config directories.

CDIST_LOCAL_SHELL
    Selects shell for local script execution, defaults to /bin/sh.

CDIST_REMOTE_SHELL
    Selects shell for remote script execution, defaults to /bin/sh.

CDIST_OVERRIDE
    Allow overwriting type parameters.

CDIST_ORDER_DEPENDENCY
    Create dependencies based on the execution order.

CDIST_REMOTE_EXEC
    Use this command for remote execution (should behave like ssh).

CDIST_REMOTE_COPY
    Use this command for remote copy (should behave like scp).

EXIT STATUS
-----------
The following exit values shall be returned:

0   Successful completion.

1   One or more host configurations failed.


AUTHORS
-------
Nico Schottelius <nico-cdist--@--schottelius.org>

CAVEATS
-------
When operating in parallel, either by operating in parallel for each host
(-p/--parallel) or by parallel jobs within a host (-j/--jobs), and depending
on target SSH server and its configuration you may encounter connection drops.
This is controlled with sshd :strong:`MaxStartups` configuration options.
You may also encounter session open refusal. This happens with ssh multiplexing
when you reach maximum number of open sessions permitted per network
connection. In this case ssh will disable multiplexing.
This limit is controlled with sshd :strong:`MaxSessions` configuration
options. For more details refer to :strong:`sshd_config`\ (5).

COPYING
-------
Copyright \(C) 2011-2013 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License v3 or later (GPLv3+).
