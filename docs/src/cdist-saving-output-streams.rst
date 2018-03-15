Saving output streams
=====================

Description
-----------
Since version 4.8.0 cdist, by default, saves output streams to local cache.
Saving output streams is implemented because important information was lost
during a config run, hidden in all other output.
Now all created output is bound to the context where it was produced.

Saving output streams include stdout and stderr of init manifest, remote
commands and for each object stdout and stderr of manifest, gencode-\* and code-\*.
Output stream files are created only if some output is produced. For more info
on these cache files see `Local cache overview <cdist-cache.html>`_.

Also, in case of an error, cdist can now exit and show all information it has
about the error.

For example:

.. code-block:: sh

    $ ./bin/cdist config -v -i ~/.cdist/manifest/init-output-streams $(cat ~/ungleich/data/opennebula-debian9-test )
    INFO: 185.203.112.42: Starting configuration run
    INFO: 185.203.112.42: Processing __myline/test
    ERROR: 185.203.112.42: Command failed: '/bin/sh -e /tmp/tmpow6cwemh/75ee6a79e32da093da23fe4a13dd104b/data/object/__myline/test/.cdist-kisrqlpw/code-local'
    return code: 1
    ---- BEGIN stdout ----
    ---- END stdout ----

    Error processing object '__myline/test'
    ========================================
    name: __myline/test
    path: /tmp/tmpow6cwemh/75ee6a79e32da093da23fe4a13dd104b/data/object/__myline/test/.cdist-kisrqlpw
    source: /home/darko/.cdist/manifest/init-output-streams
    type: /tmp/tmpow6cwemh/75ee6a79e32da093da23fe4a13dd104b/data/conf/type/__myline

    ---- BEGIN manifest:stderr ----
    myline manifest stderr

    ---- END manifest:stderr ----

    ---- BEGIN gencode-remote:stderr ----
    test gencode-remote error

    ---- END gencode-remote:stderr ----

    ---- BEGIN code-local:stderr ----
    error

    ---- END code-local:stderr ----

    ERROR: cdist: Failed to configure the following hosts: 185.203.112.42

Upon successful run execution state is saved to local cache and temporary
directory is removed.
In case of an error temporary directory is not removed and can be further
discovered.

There is also an option :strong:`-S/--disable-saving-output-streams` for
disabling saving output streams. In this case error reporting can look
like this:

.. code-block:: sh

    $ ./bin/cdist config -v -S -i ~/.cdist/manifest/init-output-streams $(cat ~/ungleich/data/opennebula-debian9-test )
    INFO: 185.203.112.42: Starting configuration run
    test stdout output streams
    test stderr output streams
    myline manifest stdout
    myline manifest stderr
    test gencode-remote error
    INFO: 185.203.112.42: Processing __myline/test
    error
    ERROR: 185.203.112.42: Command failed: '/bin/sh -e /tmp/tmpzomy0wis/75ee6a79e32da093da23fe4a13dd104b/data/object/__myline/test/.cdist-n566pqut/code-local'
    return code: 1
    ---- BEGIN stdout ----
    ---- END stdout ----

    Error processing object '__myline/test'
    ========================================
    name: __myline/test
    path: /tmp/tmpzomy0wis/75ee6a79e32da093da23fe4a13dd104b/data/object/__myline/test/.cdist-n566pqut
    source: /home/darko/.cdist/manifest/init-output-streams
    type: /tmp/tmpzomy0wis/75ee6a79e32da093da23fe4a13dd104b/data/conf/type/__myline


    ERROR: cdist: Failed to configure the following hosts: 185.203.112.42
