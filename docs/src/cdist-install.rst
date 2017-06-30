How to install cdist
====================

Requirements
-------------

Source Host
~~~~~~~~~~~

This is the machine from which you will configure target hosts.

 * /bin/sh: A posix like shell (for instance bash, dash, zsh)
 * Python >= 3.2
 * SSH client
 * sphinx (for building html docs and/or the man pages)

Target Hosts
~~~~~~~~~~~~

 * /bin/sh: A posix like shell (for instance bash, dash, zsh)
 * SSH server

Install cdist
-------------

You can install cdist either from git or as a python package.

From git
~~~~~~~~

Cloning cdist from git gives you the advantage of having
a version control in place for development of your own stuff
immediately.

To install cdist, execute the following commands:

.. code-block:: sh

    git clone https://github.com/ungleich/cdist.git
    cd cdist
    export PATH=$PATH:$(pwd -P)/bin

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

Git mirrors
^^^^^^^^^^^

If the main site is down, you can acquire cdist from one of the following sites:

 * git://github.com/telmich/cdist.git `github <https://github.com/telmich/cdist>`_
 * git://git.code.sf.net/p/cdist/code `sourceforge <https://sourceforge.net/p/cdist/code>`_

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

    DOT_CDIST_PATH=/opt/cdist make dotman

Python package
~~~~~~~~~~~~~~

Cdist is available as a python package at
`PyPi <http://pypi.python.org/pypi/cdist/>`_. You can install it using

.. code-block:: sh

    pip install cdist
