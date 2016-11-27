Trigger
=======

Description
-----------
cdist supports triggering for host installation/configuration using trigger command.
This command starts trigger server at management node, for example:

.. code-block:: sh

    $ cdist trigger -b -v -i ~/.cdist/manifest/init-for-triggered

This will start cdist trigger server in verbose mode. cdist trigger server accepts
simple requests for configuration and for installation:

* :strong:`/install/.*` for installation
* :strong:`/config/.*` for configuration.

Machines can then trigger cdist trigger server with appropriate requests.
If the request is, for example, for installation (:strong:`/install/`)
then cdist trigger server will start install command for the client host using
parameters specified at trigger server startup. For the above example that means
that client will be installed using specified initial manifest,
``~/.cdist/manifest/init-for-triggered``.
