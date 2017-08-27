cdist integration / using cdist as library
==========================================

Description
-----------

cdist can be integrate with other applications by importing cdist and other
cdist modules and setting all by hand. There are also helper functions which
aim to ease this integration. Just import **cdist.integration** and use its
functions:

* :strong:`cdist.integration.configure_hosts_simple` for configuration
* :strong:`cdist.integration.install_hosts_simple` for installation.

Functions require `host` and `manifest` parameters.
`host` can be specified as a string representing host or as iterable
of hosts. `manifest` is a path to initial manifest. For other cdist
options default values will be used. `cdist_path` parameter specifies
path to cdist executable, if it is `None` then functions will try to
find it first in local lib directory and then in PATH.

In case of cdist error :strong:`cdist.Error` exception is raised.

:strong:`WARNING`: cdist integration helper functions are not yet stable!

Examples
--------

.. code-block:: sh

    # configure host from python interactive shell
    >>> import cdist.integration
    >>> cdist.integration.configure_hosts_simple('185.203.114.185',
    ...                                          '~/.cdist/manifest/init')

    # configure host from python interactive shell, specifiying verbosity level
    >>> import cdist.integration
    >>> cdist.integration.configure_hosts_simple(
    ...     '185.203.114.185', '~/.cdist/manifest/init',
    ...     verbose=cdist.argparse.VERBOSE_TRACE)

    # configure specified dns hosts from python interactive shell
    >>> import cdist.integration
    >>> hosts = ('dns1.ungleich.ch', 'dns2.ungleich.ch', 'dns3.ungleich.ch', )
    >>> cdist.integration.configure_hosts_simple(hosts,
    ...                                          '~/.cdist/manifest/init')
