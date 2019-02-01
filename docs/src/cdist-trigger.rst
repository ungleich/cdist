Trigger
=======

Description
-----------
cdist supports triggering for host installation/configuration using trigger command.
This command starts trigger server at management node, for example:

.. code-block:: sh

    $ cdist trigger -b -v

This will start cdist trigger server in verbose mode. cdist trigger server accepts
simple requests for configuration and for installation:

* :strong:`/cdist/install/` for installation
* :strong:`/cdist/config/` for configuration.

Other configuration parameters are the same as in like cdist config (See `cdist <man1/cdist.html>`_).

Machines can then trigger cdist trigger server with appropriate requests.
If the request is, for example, for installation (:strong:`/cdist/install/`)
then cdist trigger server will start install command for the client host using
parameters specified at trigger server startup. For the above example that means
that client will be installed using default initial manifest.

When triggered cdist will try to reverse DNS lookup for host name and if
host name is dervied then it is used for running cdist config. If no
host name is resolved then IP address is used.

This command returns the following response codes to client requests:

* 200 for success
* 599 for cdist run errors
* 500 for cdist/server errors.
