cdist(1)
========

NAME
----
cdist - Usable Configuration Management


SYNOPSIS
--------

::

    cdist [-h] [-d] [-v] [-V] {banner,config,shell,install} ...

    cdist banner [-h] [-d] [-v]

    cdist config [-h] [-d] [-v] [-b] [-c CONF_DIR] [-f HOSTFILE]
                 [-i MANIFEST] [-j [JOBS]] [-n] [-o OUT_PATH] [-p] [-s]
                 [--remote-copy REMOTE_COPY] [--remote-exec REMOTE_EXEC]
                 [host [host ...]]

    cdist install [-h] [-d] [-v] [-b] [-c CONF_DIR] [-f HOSTFILE]
                  [-i MANIFEST] [-j [JOBS]] [-n] [-o OUT_PATH] [-p] [-s]
                  [--remote-copy REMOTE_COPY] [--remote-exec REMOTE_EXEC]
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

    Set log level to debug (deprecated, use -vvv instead)

.. option:: -v, --verbose

    Increase the verbosity level. Every instance of -v increments the verbosity
    level by one. Its default value is 0. There are 4 levels of verbosity. The
    order of levels from the lowest to the highest are: ERROR (0), WARNING (1),
    INFO (2) and DEBUG (3 or higher).

.. option:: -V, --version

   Show version and exit


BANNER
------
Displays the cdist banner. Useful for printing
cdist posters - a must have for every office.


CONFIG/INSTALL
--------------
Configure/install one or more hosts.

.. option:: -b, --beta

    Enable beta functionalities.
    
    Can also be enabled using CDIST_BETA env var.

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

.. option:: -i MANIFEST, --initial-manifest MANIFEST

    Path to a cdist manifest or - to read from stdin

.. option:: -j [JOBS], --jobs [JOBS]

    Specify the maximum number of parallel jobs. Global
    explorers, object prepare and object run are supported
    (currently in beta).

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

NOTES
-----
cdist detects if host is specified by IPv6 address. If so then remote_copy
command is executed with host address enclosed in square brackets 
(see :strong:`scp`\ (1)).

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

    # Install ikq05.ethz.ch with debug enabled
    % cdist install -d ikq05.ethz.ch

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

CDIST_BETA
    Enable beta functionalities.

EXIT STATUS
-----------
The following exit values shall be returned:

0   Successful completion.

1   One or more host configurations failed.


AUTHORS
-------
Originally written by Nico Schottelius <nico-cdist--@--schottelius.org>
and Steven Armstrong <steven-cdist--@--armstrong.cc>.

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

When requirements for the same object are defined in different manifests (see
example below), for example, in init manifest and in some other type manifest
and those requirements differ then dependency resolver cannot detect
dependencies right. This happens because cdist cannot prepare all objects first
and run all objects afterwards. Some object can depend on the result of type
explorer(s) and explorers are executed during object run. cdist will detect
such case and write warning message. Example for such a case:

.. code-block:: sh

    init manifest:
        __a a
        require="__e/e" __b b
        require="__f/f" __c c
        __e e
        __f f
        require="__c/c" __d d
        __g g
        __h h

    type __g manifest:
        require="__c/c __d/d" __a a

    Warning message:
        WARNING: cdisttesthost: Object __a/a already exists with requirements:
        /usr/home/darko/ungleich/cdist/cdist/test/config/fixtures/manifest/init-deps-resolver /tmp/tmp.cdist.test.ozagkg54/local/759547ff4356de6e3d9e08522b0d0807/data/conf/type/__g/manifest: set()
        /tmp/tmp.cdist.test.ozagkg54/local/759547ff4356de6e3d9e08522b0d0807/data/conf/type/__g/manifest: {'__c/c', '__d/d'}
        Dependency resolver could not handle dependencies as expected.

COPYING
-------
Copyright \(C) 2011-2017 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License v3 or later (GPLv3+).
