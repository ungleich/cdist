cdist-new-type(1)
=================

NAME
----
cdist-new-type - Create new type skeleton


SYNOPSIS
--------

::

    cdist-new-type TYPE-NAME AUTHOR-NAME AUTHOR-EMAIL [TYPE-BASE-PATH]



DESCRIPTION
-----------
cdist-new-type is a helper script that creates new type skeleton.
It is then up to the type author to finish the type.

It creates skeletons for the following files:

* man.rst
* manifest
* gencode-remote.

Upon creation it prints the path to the newly created type directory.


ARGUMENTS
---------
**TYPE-NAME**
   Name of the new type.

**AUTHOR-NAME**
   Type author's full name.

**AUTHOR-NAME**
   Type author's email.

**TYPE-BASE-PATH**
    Path to the base directory of the type. If not set it defaults
    to '$PWD/type'.


EXAMPLES
--------

.. code-block:: sh

    # Create new type __foo in ~/.cdist directory.
    $ cd ~/.cdist
    $ cdist-new-type '__foo' 'Foo Bar' 'foo.bar at foobar.org'
    /home/foo/.cdist/type/__foo


SEE ALSO
--------
:strong:`cdist`\ (1)


AUTHORS
-------

| Steven Armstrong <steven-cdist--@--armstrong.cc>
| Darko Poljak <darko.poljak--@--ungleich.ch>


COPYING
-------
Copyright \(C) 2019 Steven Armstrong, Darko Poljak. Free use of this software is
granted under the terms of the GNU General Public License v3 or later (GPLv3+).
