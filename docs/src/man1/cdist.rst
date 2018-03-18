cdist(1)
========

NAME
----
cdist - Usable Configuration Management


SYNOPSIS
--------

::

    cdist [-h] [-V] {banner,config,install,inventory,shell} ...

    cdist banner [-h] [-l LOGLEVEL] [-q] [-v]

    cdist config [-h] [-l LOGLEVEL] [-q] [-v] [-b] [-g CONFIG_FILE]
                 [-C CACHE_PATH_PATTERN] [-c CONF_DIR] [-i MANIFEST]
                 [-j [JOBS]] [-n] [-o OUT_PATH] [-R [{tar,tgz,tbz2,txz}]]
                 [-r REMOTE_OUT_DIR] [--remote-copy REMOTE_COPY]
                 [--remote-exec REMOTE_EXEC] [-I INVENTORY_DIR] [-4] [-6]
                 [-A] [-a] [-f HOSTFILE] [-p [HOST_MAX]] [-S] [-s] [-t]
                 [host [host ...]] 

    cdist install [-h] [-l LOGLEVEL] [-q] [-v] [-b] [-g CONFIG_FILE]
                  [-C CACHE_PATH_PATTERN] [-c CONF_DIR] [-i MANIFEST]
                  [-j [JOBS]] [-n] [-o OUT_PATH] [-R [{tar,tgz,tbz2,txz}]]
                  [-r REMOTE_OUT_DIR] [--remote-copy REMOTE_COPY]
                  [--remote-exec REMOTE_EXEC] [-I INVENTORY_DIR] [-4] [-6]
                  [-A] [-a] [-f HOSTFILE] [-p [HOST_MAX]] [-S] [-s] [-t]
                  [host [host ...]] 

    cdist inventory [-h] {add-host,add-tag,del-host,del-tag,list} ...

    cdist inventory add-host [-h] [-l LOGLEVEL] [-q] [-v] [-b]
                             [-g CONFIG_FILE] [-I INVENTORY_DIR]
                             [-f HOSTFILE]
                             [host [host ...]]

    cdist inventory add-tag [-h] [-l LOGLEVEL] [-q] [-v] [-b]
                            [-g CONFIG_FILE] [-I INVENTORY_DIR]
                            [-f HOSTFILE] [-T TAGFILE] [-t TAGLIST]
                            [host [host ...]]

    cdist inventory del-host [-h] [-l LOGLEVEL] [-q] [-v] [-b]
                             [-g CONFIG_FILE] [-I INVENTORY_DIR] [-a]
                             [-f HOSTFILE]
                             [host [host ...]]

    cdist inventory del-tag [-h] [-l LOGLEVEL] [-q] [-v] [-b]
                            [-g CONFIG_FILE] [-I INVENTORY_DIR] [-a]
                            [-f HOSTFILE] [-T TAGFILE] [-t TAGLIST]
                            [host [host ...]]

    cdist inventory list [-h] [-l LOGLEVEL] [-q] [-v] [-b] [-g CONFIG_FILE]
                         [-I INVENTORY_DIR] [-a] [-f HOSTFILE] [-H] [-t]
                         [host [host ...]]

    cdist shell [-h] [-l LOGLEVEL] [-q] [-v] [-s SHELL]


DESCRIPTION
-----------
cdist is the frontend executable to the cdist configuration management.
It supports different subcommands as explained below.

It is written in Python so it requires :strong:`python`\ (1) to be installed.
It requires a minimal Python version 3.2.

GENERAL
-------
All commands accept the following options:

**-h, --help**
    Show the help screen.

**-l LOGLEVEL, --log-level LOGLEVEL**
    Set the specified verbosity level. The levels, in
    order from the lowest to the highest, are: ERROR (-1),
    WARNING (0), INFO (1), VERBOSE (2), DEBUG (3) TRACE (4
    or higher). If used along with -v then -v increases
    last set value and -l overwrites last set value.

**-q, --quiet**
    Quiet mode: disables logging, including WARNING and ERROR.

**-v, --verbose**
    Increase the verbosity level. Every instance of -v
    increments the verbosity level by one. Its default
    value is 0 which includes ERROR and WARNING levels.
    The levels, in order from the lowest to the highest,
    are: ERROR (-1), WARNING (0), INFO (1), VERBOSE (2),
    DEBUG (3) TRACE (4 or higher). If used along with -l
    then -l overwrites last set value and -v increases
    last set value.

**-V, --version**
   Show version and exit.


BANNER
------
Displays the cdist banner. Useful for printing
cdist posters - a must have for every office.


CONFIG/INSTALL
--------------
Configure/install one or more hosts.
Install command is currently in beta.

**-4, --force-ipv4**
    Force to use IPv4 addresses only. No influence for
    custom remote commands.

**-6, --force-ipv6**
    Force to use IPv6 addresses only. No influence for
    custom remote commands.

**-A, --all-tagged**
    Use all hosts present in tags db. Currently in beta.

**-a, --all**
    List hosts that have all specified tags, if -t/--tag
    is specified.

**-b, --beta**
    Enable beta functionality.
    
**-C CACHE_PATH_PATTERN, --cache-path-pattern CACHE_PATH_PATTERN**
    Specify custom cache path pattern. If it is not set then
    default hostdir is used. For more info on format see
    :strong:`CACHE PATH PATTERN FORMAT` below.

**-c CONF_DIR, --conf-dir CONF_DIR**
    Add a configuration directory. Can be specified multiple times.
    If configuration directories contain conflicting types, explorers or
    manifests, then the last one found is used.

**-f HOSTFILE, --file HOSTFILE**
    Read specified file for a list of additional hosts to operate on
    or if '-' is given, read stdin (one host per line).
    If no host or host file is specified then, by default,
    read hosts from stdin. For the file format see
    :strong:`HOSTFILE FORMAT` below.

**-g CONFIG_FILE, --config-file CONFIG_FILE**
    Use specified custom configuration file.

**-I INVENTORY_DIR, --inventory INVENTORY_DIR**
    Use specified custom inventory directory. Inventory
    directory is set up by the following rules: if cdist 
    configuration resolves this value then specified
    directory is used, if HOME env var is set then
    ~/.cdit/inventory is used, otherwise distribution
    inventory directory is used.

**-i MANIFEST, --initial-manifest MANIFEST**
    Path to a cdist manifest or - to read from stdin.

**-j [JOBS], --jobs [JOBS]**
    Operate in parallel in specified maximum number of
    jobs. Global explorers, object prepare and object run
    are supported. Without argument CPU count is used by
    default. Currently in beta.

**-n, --dry-run**
    Do not execute code.

**-o OUT_PATH, --out-dir OUT_PATH**
    Directory to save cdist output in.

**-p [HOST_MAX], --parallel [HOST_MAX]**
    Operate on multiple hosts in parallel for specified
    maximum hosts at a time. Without argument CPU count is
    used by default.

**-R [{tar,tgz,tbz2,txz}], --use-archiving [{tar,tgz,tbz2,txz}]**
    Operate by using archiving with compression where
    appropriate. Supported values are: tar - tar archive,
    tgz - gzip tar archive (the default), tbz2 - bzip2 tar
    archive and txz - lzma tar archive. Currently in beta.

**-r REMOTE_OUT_PATH, --remote-out-dir REMOTE_OUT_PATH**
    Directory to save cdist output in on the target host.

**-S, --disable-saving-output-streams**
    Disable saving output streams.

**-s, --sequential**
    Operate on multiple hosts sequentially (default).

**--remote-copy REMOTE_COPY**
    Command to use for remote copy (should behave like scp).

**--remote-exec REMOTE_EXEC**
    Command to use for remote execution (should behave like ssh).

**-t, --tag**
    Host is specified by tag, not hostname/address; list
    all hosts that contain any of specified tags.
    Currently in beta.

HOSTFILE FORMAT
~~~~~~~~~~~~~~~
The HOSTFILE contains one host per line.
A comment is started with '#' and continues to the end of the line.
Any leading and trailing whitespace on a line is ignored.
Empty lines are ignored/skipped.


The Hostfile lines are processed as follows. First, all comments are
removed. Then all leading and trailing whitespace characters are stripped.
If such a line results in empty line it is ignored/skipped. Otherwise,
host string is used.

CACHE PATH PATTERN FORMAT
~~~~~~~~~~~~~~~~~~~~~~~~~
Cache path pattern specifies path for a cache directory subdirectory.
In the path, '%N' will be substituted by the target host, '%h' will
be substituted by the calculated host directory, '%P' will be substituted
by the current process id. All format codes that
:strong:`python` :strong:`datetime.strftime()` function supports, except
'%h', are supported. These date/time directives format cdist config/install
start time.

If empty pattern is specified then default calculated host directory
is used.

Calculated host directory is a hash of a host cdist operates on.

Resulting path is used to specify cache path subdirectory under which
current host cache data are saved.


INVENTORY
---------
Manage inventory database.
Currently in beta with all sub-commands.


INVENTORY ADD-HOST
------------------
Add host(s) to inventory database.

**host**
    Host(s) to add.

**-b, --beta**
    Enable beta functionality.

**-f HOSTFILE, --file HOSTFILE**
    Read additional hosts to add from specified file or
    from stdin if '-' (each host on separate line). If no
    host or host file is specified then, by default, read
    from stdin. Hostfile format is the same as config hostfile format.

**-g CONFIG_FILE, --config-file CONFIG_FILE**
    Use specified custom configuration file.

**-I INVENTORY_DIR, --inventory INVENTORY_DIR**
    Use specified custom inventory directory. Inventory
    directory is set up by the following rules: if cdist 
    configuration resolves this value then specified
    directory is used, if HOME env var is set then
    ~/.cdit/inventory is used, otherwise distribution
    inventory directory is used.


INVENTORY ADD-TAG
-----------------
Add tag(s) to inventory database.

**host**
    List of host(s) for which tags are added.

**-b, --beta**
    Enable beta functionality.

**-f HOSTFILE, --file HOSTFILE**
    Read additional hosts to add tags from specified file
    or from stdin if '-' (each host on separate line). If
    no host or host file is specified then, by default,
    read from stdin. If no tags/tagfile nor hosts/hostfile
    are specified then tags are read from stdin and are
    added to all hosts. Hostfile format is the same as config hostfile format.

**-g CONFIG_FILE, --config-file CONFIG_FILE**
    Use specified custom configuration file.

**-I INVENTORY_DIR, --inventory INVENTORY_DIR**
    Use specified custom inventory directory. Inventory
    directory is set up by the following rules: if cdist 
    configuration resolves this value then specified
    directory is used, if HOME env var is set then
    ~/.cdit/inventory is used, otherwise distribution
    inventory directory is used.

**-T TAGFILE, --tag-file TAGFILE**
    Read additional tags to add from specified file or
    from stdin if '-' (each tag on separate line). If no
    tag or tag file is specified then, by default, read
    from stdin. If no tags/tagfile nor hosts/hostfile are
    specified then tags are read from stdin and are added
    to all hosts. Tagfile format is the same as config hostfile format.

**-t TAGLIST, --taglist TAGLIST**
    Tag list to be added for specified host(s), comma
    separated values.


INVENTORY DEL-HOST
------------------
Delete host(s) from inventory database.

**host**
    Host(s) to delete.

**-a, --all**
    Delete all hosts.

**-b, --beta**
    Enable beta functionality.

**-f HOSTFILE, --file HOSTFILE**
    Read additional hosts to delete from specified file or
    from stdin if '-' (each host on separate line). If no
    host or host file is specified then, by default, read
    from stdin. Hostfile format is the same as config hostfile format.

**-g CONFIG_FILE, --config-file CONFIG_FILE**
    Use specified custom configuration file.

**-I INVENTORY_DIR, --inventory INVENTORY_DIR**
    Use specified custom inventory directory. Inventory
    directory is set up by the following rules: if cdist 
    configuration resolves this value then specified
    directory is used, if HOME env var is set then
    ~/.cdit/inventory is used, otherwise distribution
    inventory directory is used.


INVENTORY DEL-TAG
-----------------
Delete tag(s) from inventory database.

**host**
    List of host(s) for which tags are deleted.

**-a, --all**
    Delete all tags for specified host(s).

**-b, --beta**
    Enable beta functionality.

**-f HOSTFILE, --file HOSTFILE**
    Read additional hosts to delete tags for from
    specified file or from stdin if '-' (each host on
    separate line). If no host or host file is specified
    then, by default, read from stdin. If no tags/tagfile
    nor hosts/hostfile are specified then tags are read
    from stdin and are deleted from all hosts. Hostfile
    format is the same as config hostfile format.

**-g CONFIG_FILE, --config-file CONFIG_FILE**
    Use specified custom configuration file.

**-I INVENTORY_DIR, --inventory INVENTORY_DIR**
    Use specified custom inventory directory. Inventory
    directory is set up by the following rules: if cdist 
    configuration resolves this value then specified
    directory is used, if HOME env var is set then
    ~/.cdit/inventory is used, otherwise distribution
    inventory directory is used.

**-T TAGFILE, --tag-file TAGFILE**
    Read additional tags from specified file or from stdin
    if '-' (each tag on separate line). If no tag or tag
    file is specified then, by default, read from stdin.
    If no tags/tagfile nor hosts/hostfile are specified
    then tags are read from stdin and are added to all
    hosts. Tagfile format is the same as config hostfile format.

**-t TAGLIST, --taglist TAGLIST**
    Tag list to be deleted for specified host(s), comma
    separated values.


INVENTORY LIST
--------------
List inventory database.

**host**
    Host(s) to list.

**-a, --all**
    List hosts that have all specified tags, if -t/--tag
    is specified.

**-b, --beta**
    Enable beta functionality.

**-f HOSTFILE, --file HOSTFILE**
    Read additional hosts to list from specified file or
    from stdin if '-' (each host on separate line). If no
    host or host file is specified then, by default, list
    all. Hostfile format is the same as config hostfile format.

**-g CONFIG_FILE, --config-file CONFIG_FILE**
    Use specified custom configuration file.

**-H, --host-only**
    Suppress tags listing.

**-I INVENTORY_DIR, --inventory INVENTORY_DIR**
    Use specified custom inventory directory. Inventory
    directory is set up by the following rules: if cdist 
    configuration resolves this value then specified
    directory is used, if HOME env var is set then
    ~/.cdit/inventory is used, otherwise distribution
    inventory directory is used.

**-t, --tag**
    Host is specified by tag, not hostname/address; list
    all hosts that contain any of specified tags.


SHELL
-----
This command allows you to spawn a shell that enables access
to the types as commands. It can be thought as an
"interactive manifest" environment. See below for example
usage. Its primary use is for debugging type parameters.

**-s SHELL, --shell SHELL**
    Select shell to use, defaults to current shell. Used shell should
    be POSIX compatible shell.


CONFIGURATION
-------------
cdist obtains configuration data from the following sources in the following
order (from higher to lower precedence):

    #. command-line options
    #. configuration file specified at command-line
    #. configuration file specified in CDIST_CONFIG_FILE environment variable
    #. environment variables
    #. user's configuration file (first one found of ~/.cdist.cfg, $XDG_CONFIG_HOME/cdist/cdist.cfg, in specified order)
    #. system-wide configuration file (/etc/cdist.cfg).

CONFIGURATION FILE FORMAT
~~~~~~~~~~~~~~~~~~~~~~~~~
cdist configuration file is in the INI file format. Currently it supports
only [GLOBAL] section.
The possible keywords and their meanings are as follows:

:strong:`archiving`
    Use specified archiving. Valid values include:
    'none', 'tar', 'tgz', 'tbz2' and 'txz'.

:strong:`beta`
    Enable beta functionality. It recognizes boolean values from
    'yes'/'no', 'on'/'off', 'true'/'false' and '1'/'0'.

:strong:`cache_path_pattern`
    Specify cache path pattern.

:strong:`conf_dir`
    List of configuration directories separated with the character conventionally
    used by the operating system to separate search path components (as in PATH),
    such as ':' for POSIX or ';' for Windows.
    If also specified at command line then values from command line are
    appended to this value.

:strong:`init_manifest`
    Specify default initial manifest.

:strong:`inventory_dir`
    Specify inventory directory.

:strong:`jobs`
    Specify number of jobs for parallel processing. If -1 then the default,
    number of CPU's in the system is used. If 0 then parallel processing in
    jobs is disabled. If set to positive number then specified maximum
    number of processes will be used.

:strong:`local_shell`
    Shell command used for local execution.

:strong:`out_path`
    Directory to save cdist output in.

:strong:`parallel`
    Process hosts in parallel. If -1 then the default, number of CPU's in
    the system is used. If 0 then parallel processing of hosts is disabled.
    If set to positive number then specified maximum number of processes
    will be used.

:strong:`remote_copy`
    Command to use for remote copy (should behave like scp).

:strong:`remote_exec`
    Command to use for remote execution (should behave like ssh).

:strong:`remote_out_path`
    Directory to save cdist output in on the target host.

:strong:`remote_shell`
    Shell command at remote host used for remote execution.

:strong:`save_output_streams`
    Enable/disable saving output streams (enabled by default).
    It recognizes boolean values from 'yes'/'no', 'on'/'off', 'true'/'false'
    and '1'/'0'.

:strong:`verbosity`
    Set verbosity level. Valid values are: 
    'ERROR', 'WARNING', 'INFO', 'VERBOSE', 'DEBUG', 'TRACE' and 'OFF'.


FILES
-----
~/.cdist
    Your personal cdist config directory. If exists it will be
    automatically used.
~/.cdist/cache
    Local cache directory.
~/.cdist/inventory
    The home inventory directory. If ~/.cdist exists it will be used as
    default inventory directory.
cdist/conf
    The distribution configuration directory. It contains official types and
    explorers. This path is relative to cdist installation directory.
cdist/inventory
    The distribution inventory directory.
    This path is relative to cdist installation directory.
/etc/cdist.cfg
    Global cdist configuration file, if exists.
~/.cdist.cfg or $XDG_CONFIG_HOME/cdist/cdist.cfg
    Local cdist configuration file, if exists.

NOTES
-----
cdist detects if host is specified by IPv6 address. If so then remote_copy
command is executed with host address enclosed in square brackets 
(see :strong:`scp`\ (1)).

EXAMPLES
--------

.. code-block:: sh

    # Configure ikq05.ethz.ch with debug enabled
    % cdist config -vvv ikq05.ethz.ch

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
    % cdist install -vvv ikq05.ethz.ch

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

    # Add tags to specified hosts
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

    # Configure all hosts from inventory db
    $ cdist config -b -A


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

CDIST_INVENTORY_DIR
    Use this directory as inventory directory.

CDIST_BETA
    Enable beta functionality.

CDIST_CACHE_PATH_PATTERN
    Custom cache path pattern.

CDIST_CONFIG_FILE
    Custom configuration file.


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
dependencies correctly. This happens because cdist cannot prepare all objects first
and run all objects afterwards. Some object can depend on the result of type
explorer(s) and explorers are executed during object run. cdist will detect
such case and display a warning message. An example of such a case:

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
