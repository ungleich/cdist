cdist-dump(1)
=============

NAME
----
cdist-dump - Dump data from local cdist cache


SYNOPSIS
--------

::

    cdist-dump [options] [host...]



DESCRIPTION
-----------
cdist-dump is a helper script that dumps data from local cdist cache for
specified hosts. If host is not specified then all data from cache directory
is dumped. Default cache directory is '~/.cdist/cache'.

cdist-dump can be used for debugging existing types, host configuration and
new types. 


OPTIONS
-------
**-a**
   dump all

**-C CACHE-DIR**
   use specified CACHE-DIR (default: ~/.cdist/cache)

**-c**
   dump code-*

**-d DELIMITER**
   delimiter used for filename and line number prefix (default: ':')

**-E**
   dump global explorers

**-e**
   dump type explorers

**-F**
   disable filename prefix (enabled by default)

**-f**
   enable filename prefix (default)

**-g**
   dump gencode-*

**-h**
   show this help screen and exit

**-L**
   disable line number prefix (default)

**-l**
   enable line number prefix (disabled by default)

**-m**
   dump messages

**-o**
   dump executions' stdout

**-p**
   dump parameters

**-r**
   dump executions' stderr

**-V**
   show version and exit

**-v**
   increase verbosity


EXAMPLES
--------

.. code-block:: sh

    # Dump all
    % cdist-dump -a

    # Dump only code-* output
    % cdist-dump -c


SEE ALSO
--------
:strong:`cdist`\ (1)


AUTHORS
-------
Darko Poljak <darko.poljak--@--ungleich.ch>


COPYING
-------
Copyright \(C) 2019 Darko Poljak. Free use of this software is
granted under the terms of the GNU General Public License v3 or later (GPLv3+).
