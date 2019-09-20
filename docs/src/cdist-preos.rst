PreOS
=====

Description
-----------
With cdist you can install and configure new machines. You can use cdist to
create PreOS, minimal OS which purpose is to boot new machine.
After PreOS is booted machine is ready for installing desired OS and
then it is ready for configuration.

PreOS creation
--------------
With cdist you can create PreOS.
Currently supported PreOS-es include:

* debian
* ubuntu
* devuan.

PreOS is created using cdist preos command. preos command has subcommands that
create the desired PreOS.

For example, to create ubuntu PreOS:

.. code-block:: sh

    $ cdist preos ubuntu /preos/preos-ubuntu -B -C \
        -k ~/.ssh/id_rsa.pub -p /preos/pxe-ubuntu

For more info about available options see cdist manual page.

This will bootstrap (``-B``) ubuntu PreOS in ``/preos/preos-ubuntu`` directory, it
will be configured (``-C``) using default built-in initial manifest and with
specified ssh authorized key (``-k``).
After bootstrapping and configuration PXE
boot directory will be created (``-p``) in ``/preos/pxe-ubuntu``.

After PreOS is created new machines can be booted using created PXE (after
proper dhcp, tftp setting).

Since PreOS is configured with ssh authorized key it can be accessed throguh
ssh, i.e. it can be further installed and configured with cdist.

Implementing new PreOS sub-command
----------------------------------
preos command is implemented as a plugin system. This plugin system scans for
preos subcommands in ``cdist/preos/`` distribution directory and also in
``~/.cdist/preos/`` directory if it exists.

preos subcommand is a module or a class that satisfies the following:

* it has attribute ``_cdist_preos`` set to ``True``
* it has function/method ``commandline``.

For a module based preos subcommand ``commandline`` function accepts a module
object as its first argument and the list of command line
arguments (``sys.argv[2:]``).

For a class preos subcommand ``commandline`` method should be staticmethod and
it accepts a class object as its first argument and the list of command line
arguments(``sys.argv[2:]``).

If preos scanning finds a module/class that has ``_cdist_preos`` set
to ``True`` and it has function/method ``commandline`` then this module/class is
registered to preos subcommands. The name of the command is set to ``_preos_name``
attribute if it exists, otherwise it is set to the module/class name, lowercase.
When registered preos subcommand is specified as preos command then ``commandline``
will be called with first argument set to module/class object and second argument
set to ``sys.argv[2:]``.

Example writing new dummy preos sub-command
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module based preos:
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

    $ cdist preos -h
    usage: cdist preos [-h] preos

    Create PreOS

    positional arguments:
      preos       PreOS to create, one of: {'netbsd', 'debian', 'ubuntu'}

    optional arguments:
      -h, --help  show this help message and exit
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
    usage: cdist preos [-h] preos

    Create PreOS

    positional arguments:
      preos       PreOS to create, one of: {'freebsd', 'debian', 'ubuntu'}

    optional arguments:
      -h, --help  show this help message and exit
    $ cdist preos freebsd
    FreeBSD dummy preos: []

In the ``commandline`` function/method you have all the freedom to actually create
PreOS.
