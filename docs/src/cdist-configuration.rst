Configuration
=============

Description
-----------
cdist obtains configuration data from the following sources in the following
order:

    #. command-line options
    #. configuration file specified at command-line using -g command line option
    #. configuration file specified in CDIST_CONFIG_FILE environment variable
    #. environment variables
    #. user's configuration file (first one found of ~/.cdist.cfg, $XDG_CONFIG_HOME/cdist/cdist.cfg, in specified order)
    #. system-wide configuration file (/etc/cdist.cfg)

if one exists.

Configuration source with lower ordering number from above has a higher
precedence. Configuration option value read from source with higher
precedence will overwrite option value, if exists, read from source with
lower precedence. That means that command-line option wins them all.

Users can decide on the local conifguration file location. It can be either
~/.cdist.cfg or $XDG_CONFIG_HOME/cdist/cdist.cfg. Note that, if both exist,
then ~/.cdist.cfg is used.

For a per-project configuration, particular environment variables or better,
CDIST_CONFIG_FILE environment variable or -g CONFIG_FILE command line option,
can be used.

Config file format
------------------
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

:strong:`verbosity`
    Set verbosity level. Valid values are: 
    'ERROR', 'WARNING', 'INFO', 'VERBOSE', 'DEBUG', 'TRACE' and 'OFF'.
