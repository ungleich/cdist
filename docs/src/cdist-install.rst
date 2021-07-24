How to install cdist
====================

Requirements
-------------

Source Host
~~~~~~~~~~~

This is the machine from which you will configure target hosts.

 * /bin/sh: A POSIX like shell (for instance bash, dash, zsh)
 * Python >= 3.5
 * SSH client
 * sphinx with the rtd theme (for building html docs and/or the man pages)

Target Hosts
~~~~~~~~~~~~

 * /bin/sh: A POSIX like shell (for instance bash, dash, zsh)
 * SSH server

Install cdist
-------------

From git
~~~~~~~~

Cloning cdist from git gives you the advantage of having
a version control in place for development of your own stuff
immediately.

To install cdist, execute the following commands:

.. code-block:: sh

    git clone https://code.ungleich.ch/ungleich-public/cdist.git
    cd cdist
    export PATH=$PATH:$(pwd -P)/bin

From version 4.2.0 cdist tags and releases are signed.
You can get GPG public key used for signing `here <_static/pgp-key-EFD2AE4EC36B6901.asc>`_.
It is assumed that you are familiar with *git* ways of signing and verification.

You can also get cdist from `github mirror <https://github.com/ungleich/cdist>`_.

To install cdist with distutils from cloned repository, first you have to
create version.py:

.. code-block:: sh

    ./bin/cdist-build-helper version

Then you install it with:

.. code-block:: sh

   make install

or with:

.. code-block:: sh

   make install-user

to install it into user *site-packages* directory.
Or directly with distutils:

.. code-block:: sh

    python setup.py install

Note that `bin/cdist-build-helper` script is intended for cdist maintainers.


Available versions in git
^^^^^^^^^^^^^^^^^^^^^^^^^

 * The active development takes place in the **master** branch
 * The released versions can be found in the tags

Other branches may be available for features or bugfixes, but they
may vanish at any point. To select a specific branch use

.. code-block:: sh

    # Generic code
    git checkout -b <localbranchname> origin/<branchname>

So for instance if you want to use and stay with version 4.1, you can use

.. code-block:: sh

    git checkout -b 4.1 origin/4.1

Building and using documentation (man and html)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If you want to build and use the documentation, run:

.. code-block:: sh

    make docs

Documentation comes in two formats, man pages and full HTML
documentation. Documentation is built into distribution's
docs/dist directory. man pages are in docs/dist/man and
HTML documentation in docs/dist/html.

If you want to use man pages, run:

.. code-block:: sh

    export MANPATH=$MANPATH:$(pwd -P)/docs/dist/man

Or you can move man pages from docs/dist/man directory to some
other directory and add it to MANPATH.

Full HTML documentation can be accessed at docs/dist/html/index.html.

You can also build only man pages or only html documentation, for
only man pages run:

.. code-block:: sh

    make man

for only html documentation run:

.. code-block:: sh

    make html

You can also build man pages for types in your ~/.cdist directory:

.. code-block:: sh

    make dotman

Built man pages are now in docs/dist/man directory. If you have
some other custom .cdist directory, e.g. /opt/cdist then use:

.. code-block:: sh

    make DOT_CDIST_PATH=/opt/cdist dotman

Note that `dotman`-target has to be built before a `make docs`-run, otherwise
the custom man-pages are not picked up.

Python package
~~~~~~~~~~~~~~

Cdist is available as a python package at
`PyPi <http://pypi.python.org/pypi/cdist/>`_. You can install it using

.. code-block:: sh

    pip install cdist

Installing from source with signature verification
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you want to install cdist from signed source and verify it, first you need to
download cdist archive and its detached signature.

Get both, *cdist-x.y.z.tar.gz* and *cdist-x.y.z.tar.gz.asc* from release
notes of the desired tag *x.y.z* at
`cdist git repository <https://code.ungleich.ch/ungleich-public/cdist/-/tags>`_.

Get GPG public key used for signing `here <_static/pgp-key-EFD2AE4EC36B6901.asc>`_
and import it into GPG.

Now cdist source archive can be verified using `gpg`, e.g. to verify `cdist-6.2.0`:

.. code-block:: sh

    $ gpg --verify cdist-6.2.0.tar.gz.asc cdist-6.2.0.targ.gz
    gpg: Signature made Sat Nov 30 23:14:19 2019 CET
    gpg:                using RSA key 69767822F3ECC3C349C1EFFFEFD2AE4EC36B6901
    gpg: Good signature from "ungleich GmbH (ungleich FOSS) <foss@ungleich.ch>" [ultimate]

Further steps are the same as for `installing from git <cdist-install.html#from-git>`_.
