PreOS
=====

Description
-----------
With cdist you can install and configure new machines. You can use cdist to
create PreOS, minimal OS whose purpose is to boot a new machine.
After PreOS is booted, the machine is ready for installing the desired OS and
afterwards it is ready for configuration.

PreOS creation
--------------
With cdist you can create PreOS.
Currently supported PreOS-es include:

* debian
* ubuntu
* devuan

PreOS is created using the ``cdist preos`` command.
This command has subcommands that determine the desired PreOS.

For example, to create an ubuntu PreOS:

.. code-block:: sh

    $ cdist preos ubuntu /preos/preos-ubuntu -B -C \
        -k ~/.ssh/id_rsa.pub -p /preos/pxe-ubuntu

For more info about the available options see the cdist manual page.

This will bootstrap (``-B``) ubuntu PreOS in the ``/preos/preos-ubuntu``
directory, it will be configured (``-C``) using default the built-in initial
manifest and with specified ssh authorized key (``-k``).
After bootstrapping and configuration, the PXE boot directory will be
created (``-p``) in ``/preos/pxe-ubuntu``.

After PreOS is created, new machines can be booted using the created PXE
(after proper dhcp and tftp settings).

Since PreOS is configured with ssh authorized key it can be accessed through
ssh, i.e. it can be further installed and configured with cdist.

Implementing a new PreOS sub-command
------------------------------------
preos command is implemented as a plugin system. This plugin system scans for
preos subcommands in the ``cdist/preos/`` distribution directory and also in
``~/.cdist/preos/`` directory if it exists.

preos subcommand is a module or a class that satisfies the following:

* it has the attribute ``_cdist_preos`` set to ``True``
* it defines a function/method ``commandline``.

For a module-based preos subcommand, the ``commandline`` function accepts a
module object as its first argument and the list of command line
arguments (``sys.argv[2:]``).

For a class-based preos subcommand ``commandline`` method should be
static-method and must accept a class as its first argument and the
list of command line arguments (``sys.argv[2:]``).

If preos scanning finds a module/class that has ``_cdist_preos`` set
to ``True`` and a function/method ``commandline`` then this module/class is
registered to preos subcommands. The name of the command is set to ``_preos_name``
attribute if defined in the module/class, defaulting to the module/class name in lowercase.
When a registered preos subcommand is specified, ``commandline``
will be called with the first argument set to module/class and the second
argument set to ``sys.argv[2:]``.

Example of writing new dummy preos sub-command
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module-based preos:
^^^^^^^^^^^^^^^^^^^

#. Create directory ``~/.cdist/preos/`` if it does not exist
#. Create ``~/.cdist/preos/netbsd.py`` with the following contents:

.. code-block:: python

    _preos_name = 'netbsd'
    _cdist_preos = True

    def commandline(cls, args):
        print("NetBSD PreOS: {}".format(args))

When you try to run this new preos you will get:

.. code-block:: sh

    $ cdist preos -L
    Available PreOS-es:
        - debian
        - devuan
        - netbsd
        - ubuntu
    $ cdist preos netbsd
    NetBSD PreOS: []

Class based preos:
^^^^^^^^^^^^^^^^^^

#. Create directory ``~/.cdist/preos/`` if it does not exist
#. Create ``~/.cdist/preos/freebsd.py`` with the following contents:

.. code-block:: python

    class FreeBSD(object):
        _cdist_preos = True

        @classmethod
        def commandline(cls, args):
            print("FreeBSD dummy preos: {}".format(args))

When you try to run this new preos you will get:

.. code-block:: sh

    $ cdist preos -h
    Available PreOS-es:
        - debian
        - devuan
        - freebsd
        - ubuntu
    $ cdist preos freebsd
    FreeBSD dummy preos: []

In the ``commandline`` function/method you have all the freedom to actually create
a PreOS.
