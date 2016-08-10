cdist-type__staged_file(7)
==========================

NAME
----
cdist-type__staged_file - Manage staged files


DESCRIPTION
-----------
Manages a staged file that is downloaded on the server (the machine running
cdist) and then deployed to the target host using the __file type.


REQUIRED PARAMETERS
-------------------
source
   the URL from which to retrieve the source file.
   e.g.

   * https://dl.bintray.com/mitchellh/consul/0.4.1_linux_amd64.zip
   * file:///path/to/local/file

cksum
   the output of running the command: `cksum $source-file`
   e.g.::

      $ echo foobar > /tmp/foobar
      $ cksum /tmp/foobar
      857691210 7 /tmp/foobar

   If either checksum or file size has changed the file will be
   (re)fetched from the --source. The file name can be omitted and is
   ignored if given.


OPTIONAL PARAMETERS
-------------------
fetch-command
   the command used to fetch the staged file using printf formatting.
   Where a single %s will be replaced with the value of the given --source
   parameter. The --fetch-command is expected to output the fetched file to
   stdout.
   Defaults to 'curl -s -L "%s"'.

group
   see cdist-type__file

owner
   see cdist-type__file

mode
   see cdist-type__file

prepare-command
   the optional command used to prepare or preprocess the staged file for later
   use by the file type.
   If given, it must be a string in printf formatting where a single %s will
   be replaced with the last segment (filename) of the value of the given
   --source parameter.
   It is executed in the same directory into which the fetched file has been
   saved. The --prepare-command is expected to output the final file to stdout.

   So for example given a --source of https://example.com/my-zip.zip, and a
   --prepare-command of 'unzip -p "%s"', the code `unzip -p "my-zip.zip"` will
   be executed in the folder containing the downloaded file my-zip.zip.
   A more complex example might be --prepare-command 'tar -xz "%s"; cat path/from/archive'
stage-dir
   the directory in which to store downloaded and prepared files.
   Defaults to '/var/tmp/cdist/__staged_file'

state
   see cdist-type__file


EXAMPLES
--------

.. code-block:: sh

    __staged_file /usr/local/bin/consul \
       --source file:///path/to/local/copy/consul \
       --cksum '428915666 15738724' \
       --state present \
       --group root \
       --owner root \
       --mode 755

    __staged_file /usr/local/bin/consul \
       --source https://dl.bintray.com/mitchellh/consul/0.4.1_linux_amd64.zip \
       --cksum '428915666 15738724' \
       --fetch-command 'curl -s -L "%s"' \
       --prepare-command 'unzip -p "%s"' \
       --state present \
       --group root \
       --owner root \
       --mode 755


SEE ALSO
--------
:strong:`cdist-type__file`\ (7)


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2015 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
