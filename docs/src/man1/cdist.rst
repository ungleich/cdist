cdist(1)
========

NAME
----
cdist - Usable Configuration Management


SYNOPSIS
--------

::

    cdist [-h] [-d] [-v] [-V] {banner,config,install,inventory,preos,shell,trigger} ...

    cdist banner [-h] [-d] [-v]

    cdist config [-h] [-d] [-v] [-b] [-C CACHE_PATH_PATTERN] [-c CONF_DIR]
                 [-i MANIFEST] [-j [JOBS]] [-n] [-o OUT_PATH]
                 [--remote-copy REMOTE_COPY] [--remote-exec REMOTE_EXEC]
                 [-I INVENTORY_DIR] [-A] [-a] [-f HOSTFILE] [-p] [-s] [-t]
                 [host [host ...]] 

    cdist install [-h] [-d] [-v] [-b] [-C CACHE_PATH_PATTERN] [-c CONF_DIR]
                  [-i MANIFEST] [-j [JOBS]] [-n] [-o OUT_PATH]
                  [--remote-copy REMOTE_COPY] [--remote-exec REMOTE_EXEC]
                  [-I INVENTORY_DIR] [-A] [-a] [-f HOSTFILE] [-p] [-s] [-t]
                  [host [host ...]] 

    cdist inventory [-h] [-d] [-v] [-b] [-I INVENTORY_DIR]
                    {add-host,add-tag,del-host,del-tag,list} ...

    cdist inventory add-host [-h] [-d] [-v] [-b] [-I INVENTORY_DIR]
                             [-f HOSTFILE]
                             [host [host ...]]

    cdist inventory add-tag [-h] [-d] [-v] [-b] [-I INVENTORY_DIR]
                            [-f HOSTFILE] [-T TAGFILE] [-t TAGLIST]
                            [host [host ...]]

    cdist inventory del-host [-h] [-d] [-v] [-b] [-I INVENTORY_DIR] [-a]
                             [-f HOSTFILE]
                             [host [host ...]]

    cdist inventory del-tag [-h] [-d] [-v] [-b] [-I INVENTORY_DIR] [-a]
                            [-f HOSTFILE] [-T TAGFILE] [-t TAGLIST]
                            [host [host ...]]

    cdist inventory list [-h] [-d] [-v] [-b] [-I INVENTORY_DIR] [-a]
                         [-f HOSTFILE] [-H] [-t]
                         [host [host ...]]

    cdist preos [-h] preos

    cdist preos debian [-h] [-d] [-v] [-b] [-a ARCH] [-B] [-C]
                       [-c CDIST_PARAMS] [-e REMOTE_EXEC] [-i MANIFEST]
                       [-k [KEYFILE [KEYFILE ...]]] [-m MIRROR]
                       [-p PXE_BOOT_DIR] [-r] [-S SCRIPT] [-s SUITE]
                       [-t TRIGGER_COMMAND] [-y REMOTE_COPY]
                       target_dir

    cdist preos ubuntu [-h] [-d] [-v] [-b] [-a ARCH] [-B] [-C]
                       [-c CDIST_PARAMS] [-e REMOTE_EXEC] [-i MANIFEST]
                       [-k [KEYFILE [KEYFILE ...]]] [-m MIRROR]
                       [-p PXE_BOOT_DIR] [-r] [-S SCRIPT] [-s SUITE]
                       [-t TRIGGER_COMMAND] [-y REMOTE_COPY]
                       target_dir

    cdist shell [-h] [-d] [-v] [-s SHELL]

    cdist trigger [-h] [-d] [-v] [-b] [-C CACHE_PATH_PATTERN] [-c CONF_DIR]
                  [-i MANIFEST] [-j [JOBS]] [-n] [-o OUT_PATH]
                  [--remote-copy REMOTE_COPY] [--remote-exec REMOTE_EXEC]
                  [-6] [-H HTTP_PORT]


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

    Increase log level, be more verbose. Use it more than once to increase
    log level. The order of levels from the lowest to the highest are:
    ERROR, WARNING, INFO, DEBUG.

.. option:: -V, --version

   Show version and exit


BANNER
------
Displays the cdist banner. Useful for printing
cdist posters - a must have for every office.


CONFIG/INSTALL
--------------
Configure/install one or more hosts.

.. option:: -A, --all-tagged

    use all hosts present in tags db

.. option:: -a, --all

    list hosts that have all specified tags, if -t/--tag
    is specified

.. option:: -b, --beta

    Enable beta functionalities.

    Can also be enabled using CDIST_BETA env var.

.. option:: -C CACHE_PATH_PATTERN, --cache-path-pattern CACHE_PATH_PATTERN

    Sepcify custom cache path pattern. It can also be set by
    CDIST_CACHE_PATH_PATTERN environment variable. If it is not set then
    default hostdir is used. For more info on format see
    :strong:`CACHE PATH PATTERN FORMAT` below.

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
    read hosts from stdin. For the file format see
    :strong:`HOSTFILE FORMAT` below.

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Inventory
    directory is set up by the following rules: if this
    argument is set then specified directory is used, if
    CDIST_INVENTORY_DIR env var is set then its value is
    used, if HOME env var is set then ~/.cdit/inventory is
    used, otherwise distribution inventory directory is
    used.

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

CACHE PATH PATTERN FORMAT
~~~~~~~~~~~~~~~~~~~~~~~~~
Cache path pattern specifies path for a cache directory subdirectory.
In the path, '%h' will be substituted by the calculated host directory,
'%P' will be substituted by the current process id. All format codes
that :strong:`python` :strong:`datetime.strftime()` function supports, except
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

.. option:: host

    host(s) to add

.. option:: -b, --beta

    Enable beta functionalities. Beta functionalities
    include inventory command with all sub-commands and
    all options; config sub-command options: -j/--jobs,
    -t/--tag, -a/--all.

    Can also be enabled using CDIST_BETA env var.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to add from specified file or
    from stdin if '-' (each host on separate line). If no
    host or host file is specified then, by default, read
    from stdin. Hostfile format is the same as config hostfile format.

.. option:: -h, --help

    show this help message and exit

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Inventory
    directory is set up by the following rules: if this
    argument is set then specified directory is used, if
    CDIST_INVENTORY_DIR env var is set then its value is
    used, if HOME env var is set then ~/.cdist/inventory is
    used, otherwise distribution inventory directory is
    used.


INVENTORY ADD-TAG
-----------------
Add tag(s) to inventory database.

.. option:: host

    list of host(s) for which tags are added

.. option:: -b, --beta

    Enable beta functionalities. Beta functionalities
    include inventory command with all sub-commands and
    all options; config sub-command options: -j/--jobs,
    -t/--tag, -a/--all.

    Can also be enabled using CDIST_BETA env var.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to add tags from specified file
    or from stdin if '-' (each host on separate line). If
    no host or host file is specified then, by default,
    read from stdin. If no tags/tagfile nor hosts/hostfile
    are specified then tags are read from stdin and are
    added to all hosts. Hostfile format is the same as config hostfile format.

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Inventory
    directory is set up by the following rules: if this
    argument is set then specified directory is used, if
    CDIST_INVENTORY_DIR env var is set then its value is
    used, if HOME env var is set then ~/.cdist/inventory is
    used, otherwise distribution inventory directory is
    used.

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


INVENTORY DEL-HOST
------------------
Delete host(s) from inventory database.

.. option:: host

    host(s) to delete

.. option:: -a, --all

    Delete all hosts

.. option:: -b, --beta

    Enable beta functionalities. Beta functionalities
    include inventory command with all sub-commands and
    all options; config sub-command options: -j/--jobs,
    -t/--tag, -a/--all.

    Can also be enabled using CDIST_BETA env var.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to delete from specified file or
    from stdin if '-' (each host on separate line). If no
    host or host file is specified then, by default, read
    from stdin. Hostfile format is the same as config hostfile format.

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Inventory
    directory is set up by the following rules: if this
    argument is set then specified directory is used, if
    CDIST_INVENTORY_DIR env var is set then its value is
    used, if HOME env var is set then ~/.cdist/inventory is
    used, otherwise distribution inventory directory is
    used.


INVENTORY DEL-TAG
-----------------
Delete tag(s) from inventory database.

.. option:: host

    list of host(s) for which tags are deleted

.. option:: -a, --all

    Delete all tags for specified host(s)

.. option:: -b, --beta

    Enable beta functionalities. Beta functionalities
    include inventory command with all sub-commands and
    all options; config sub-command options: -j/--jobs,
    -t/--tag, -a/--all.

    Can also be enabled using CDIST_BETA env var.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to delete tags for from
    specified file or from stdin if '-' (each host on
    separate line). If no host or host file is specified
    then, by default, read from stdin. If no tags/tagfile
    nor hosts/hostfile are specified then tags are read
    from stdin and are deleted from all hosts. Hostfile
    format is the same as config hostfile format.

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Inventory
    directory is set up by the following rules: if this
    argument is set then specified directory is used, if
    CDIST_INVENTORY_DIR env var is set then its value is
    used, if HOME env var is set then ~/.cdist/inventory is
    used, otherwise distribution inventory directory is
    used.

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


INVENTORY LIST
--------------
List inventory database.

.. option::  host

    host(s) to list

.. option:: -a, --all

    list hosts that have all specified tags, if -t/--tag
    is specified

.. option:: -b, --beta

    Enable beta functionalities. Beta functionalities
    include inventory command with all sub-commands and
    all options; config sub-command options: -j/--jobs,
    -t/--tag, -a/--all.

    Can also be enabled using CDIST_BETA env var.

.. option:: -f HOSTFILE, --file HOSTFILE

    Read additional hosts to list from specified file or
    from stdin if '-' (each host on separate line). If no
    host or host file is specified then, by default, list
    all. Hostfile format is the same as config hostfile format.

.. option:: -H, --host-only

    Suppress tags listing

.. option:: -I INVENTORY_DIR, --inventory INVENTORY_DIR

    Use specified custom inventory directory. Inventory
    directory is set up by the following rules: if this
    argument is set then specified directory is used, if
    CDIST_INVENTORY_DIR env var is set then its value is
    used, if HOME env var is set then ~/.cdist/inventory is
    used, otherwise distribution inventory directory is
    used.

.. option:: -t, --tag

    host is specified by tag, not hostname/address; list
    all hosts that contain any of specified tags


PREOS
-----
Create PreOS. Currently, the following PreOS-es are supported:

* debian
* ubuntu


PREOS DEBIAN
------------

.. option:: target_dir

    target directory where PreOS will be bootstrapped

.. option:: -a ARCH, --arch ARCH

    target debootstrap architecture, by default 'amd64'

.. option:: -B, --bootstrap

    do bootstrap step

.. option:: -b, --beta

    Enable beta functionalities.

    Can also be enabled using CDIST_BETA env var.

.. option:: -C, --configure

    do configure step

.. option:: -c CDIST_PARAMS, --cdist-params CDIST_PARAMS

    parameters that will be passed to cdist config, by
    default '-v' is used

.. option:: -d, --debug

    Set log level to debug

.. option:: -e REMOTE_EXEC, --remote-exec REMOTE_EXEC

    remote exec that cdist config will use, by default
    internal script is used

.. option:: -h, --help

    show this help message and exit

.. option:: -i MANIFEST, --init-manifest MANIFEST

    init manifest that cdist config will use, by default
    internal init manifest is used

.. option:: -k [KEYFILE [KEYFILE ...]], --keyfile [KEYFILE [KEYFILE ...]]

    ssh key files that will be added to cdist config;
    '``__ssh_authorized_keys root ...``' type is appended to initial manifest

.. option:: -m MIRROR, --mirror MIRROR

    use specified mirror for debootstrap

.. option:: -p PXE_BOOT_DIR, --pxe-boot-dir PXE_BOOT_DIR

    PXE boot directory

.. option:: -r, --rm-bootstrap-dir

    remove target directory after finishing

.. option:: -S SCRIPT, --script SCRIPT

    use specified script for debootstrap

.. option:: -s SUITE, --suite SUITE

    suite used for debootstrap, by default 'stable'

.. option:: -t TRIGGER_COMMAND, --trigger-command TRIGGER_COMMAND

    trigger command that will be added to cdist config;
    '``__cdist_preos_trigger http ...``' type is appended to initial manifest

.. option:: -v, --verbose

    Set log level to info, be more verbose

.. option:: -y REMOTE_COPY, --remote-copy REMOTE_COPY

    remote copy that cdist config will use, by default
    internal script is used


PREOS UBUNTU
------------

.. option:: target_dir

    target directory where PreOS will be bootstrapped

.. option:: -a ARCH, --arch ARCH

    target debootstrap architecture, by default 'amd64'

.. option:: -B, --bootstrap

    do bootstrap step

.. option:: -b, --beta

    Enable beta functionalities.

    Can also be enabled using CDIST_BETA env var.

.. option:: -C, --configure

    do configure step

.. option:: -c CDIST_PARAMS, --cdist-params CDIST_PARAMS

    parameters that will be passed to cdist config, by
    default '-v' is used

.. option:: -d, --debug

    Set log level to debug

.. option:: -e REMOTE_EXEC, --remote-exec REMOTE_EXEC

    remote exec that cdist config will use, by default
    internal script is used

.. option:: -h, --help

    show this help message and exit

.. option:: -i MANIFEST, --init-manifest MANIFEST

    init manifest that cdist config will use, by default
    internal init manifest is used

.. option:: -k [KEYFILE [KEYFILE ...]], --keyfile [KEYFILE [KEYFILE ...]]

    ssh key files that will be added to cdist config;
    '``__ssh_authorized_keys root ...``' type is appended to initial manifest

.. option:: -m MIRROR, --mirror MIRROR

    use specified mirror for debootstrap

.. option:: -p PXE_BOOT_DIR, --pxe-boot-dir PXE_BOOT_DIR

    PXE boot directory

.. option:: -r, --rm-bootstrap-dir

    remove target directory after finishing

.. option:: -S SCRIPT, --script SCRIPT

    use specified script for debootstrap

.. option:: -s SUITE, --suite SUITE

    suite used for debootstrap, by default 'xenial'

.. option:: -t TRIGGER_COMMAND, --trigger-command TRIGGER_COMMAND

    trigger command that will be added to cdist config;
    '``__cdist_preos_trigger http ...``' type is appended to initial manifest

.. option:: -v, --verbose

    Set log level to info, be more verbose

.. option:: -y REMOTE_COPY, --remote-copy REMOTE_COPY

    remote copy that cdist config will use, by default
    internal script is used


SHELL
-----
This command allows you to spawn a shell that enables access
to the types as commands. It can be thought as an
"interactive manifest" environment. See below for example
usage. Its primary use is for debugging type parameters.

.. option:: -s SHELL, --shell SHELL

    Select shell to use, defaults to current shell. Used shell should
    be POSIX compatible shell.


TRIGGER
-------
Start trigger (simple http server) that waits for connections. When host
connects then it triggers config or install command and then cdist
config/install is executed which configures/installs host.
Request path recognizes following requests:

* :strong:`/config/.*` for config
* :strong:`/install/.*` for install.


.. option:: -6, --ipv6

    Listen to both IPv4 and IPv6 (instead of only IPv4)

.. option:: -b, --beta

    Enable beta functionalities.

    Can also be enabled using CDIST_BETA env var.

.. option:: -C CACHE_PATH_PATTERN, --cache-path-pattern CACHE_PATH_PATTERN

    Sepcify custom cache path pattern. It can also be set by
    CDIST_CACHE_PATH_PATTERN environment variable. If it is not set then
    default hostdir is used. For more info on format see
    :strong:`CACHE PATH PATTERN FORMAT` below.

.. option:: -c CONF_DIR, --conf-dir CONF_DIR

    Add configuration directory (can be repeated, last one wins)

.. option:: -d, --debug

    Set log level to debug

.. option:: -H HTTP_PORT, --http-port HTTP_PORT

    Create trigger listener via http on specified port

.. option:: -h, --help

    show this help message and exit

.. option:: -i MANIFEST, --initial-manifest MANIFEST

    path to a cdist manifest or '-' to read from stdin.

.. option:: -j [JOBS], --jobs [JOBS]

    Specify the maximum number of parallel jobs, currently
    only global explorers are supported

.. option:: -n, --dry-run

    do not execute code

.. option:: -o OUT_PATH, --out-dir OUT_PATH

    directory to save cdist output in

.. option:: --remote-copy REMOTE_COPY

    Command to use for remote copy (should behave like scp)

.. option:: --remote-exec REMOTE_EXEC

    Command to use for remote execution (should behave like ssh)

.. option:: -v, --verbose

    Set log level to info, be more verbose


FILES
-----
~/.cdist
    Your personal cdist config directory. If exists it will be
    automatically used.
~/.cdist/inventory
    The home inventory directory. If ~/.cdist exists it will be used as
    default inventory directory.
~/.cdist/preos
    PreOS plugins directory, if existing.
cdist/conf
    The distribution configuration directory. It contains official types and
    explorers. This path is relative to cdist installation directory.
cdist/inventory
    The distribution inventory directory.
    This path is relative to cdist installation directory.
cdist/preos
    The distribution PreOS plugins directory.

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

    # Configure all hosts from inventory db
    $ cdist config -b -A

    # Create default debian PreOS in debug mode with config
    # trigger command
    $ cdist preos debian /preos/preos-debian -b -d -C \
        -k ~/.ssh/id_rsa.pub -p /preos/pxe-debian \
        -t "/usr/bin/curl 192.168.111.5:3000/config/"

    # Create ubuntu PreOS with install trigger command
    $ cdist preos ubuntu /preos/preos-ubuntu -b -C \
        -k ~/.ssh/id_rsa.pub -p /preos/pxe-ubuntu \
        -t "/usr/bin/curl 192.168.111.5:3000/install/"

    # Start trigger in verbose mode that will configure host using specified
    # init manifest
    % cdist trigger -b -v -i ~/.cdist/manifest/init-for-triggered


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
    Enable beta functionalities.

CDIST_CACHE_PATH_PATTERN
    Custom cache path pattern.

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
example below) in init manifest and in some other type manifest and they differs
then dependency resolver cannot detect dependencies right. This happens because
cdist cannot prepare all objects first and then run objects because some
object can depend on the result of type explorer(s) and explorers are executed
during object run. cdist will detect such case and write warning message.
Example for such a case:

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
Copyright \(C) 2011-2013 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License v3 or later (GPLv3+).
