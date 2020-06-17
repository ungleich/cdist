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
    #. in-distribution configuration file (cdist/conf/cdist.cfg)
    #. system-wide configuration file (/etc/cdist.cfg)

if one exists.

Configuration source with lower ordering number from above has a higher
precedence. Configuration option value read from source with higher
precedence will overwrite option value, if exists, read from source with
lower precedence. That means that command-line option wins them all.

Users can decide on the local configuration file location. It can be either
~/.cdist.cfg or $XDG_CONFIG_HOME/cdist/cdist.cfg. Note that, if both exist,
then ~/.cdist.cfg is used.

For a per-project configuration, particular environment variables or better,
CDIST_CONFIG_FILE environment variable or -g CONFIG_FILE command line option,
can be used.

Config file format
------------------

cdist configuration file is in the INI file format. Currently it supports
only [GLOBAL] section.

Here you can find configuration file skeleton:

.. literalinclude:: cdist.cfg.skeleton
    :language: ini
