cdist-type__block(7)
====================

NAME
----
cdist-type__block - Manage blocks of text in files


DESCRIPTION
-----------
Manage a block of text in an existing file.
The block is identified using the prefix and suffix parameters.
Everything between prefix and suffix is considered to be a managed block
of text.


REQUIRED PARAMETERS
-------------------
text
   the text to manage.
   If text is '-' (dash), take what was written to stdin as the text.


OPTIONAL PARAMETERS
-------------------
file
   the file in which to manage the text block.
   Defaults to object_id.

prefix
   the prefix to add before the text.
   Defaults to #cdist:__block/$__object_id

suffix
   the suffix to add after the text.
   Defaults to #/cdist:__block/$__object_id

state
   'present' or 'absent', defaults to 'present'


MESSAGES
--------
add
   block was added
update
   block was updated/changed
remove
   block was removed


EXAMPLES
--------

.. code-block:: sh

    # text from argument
    __block /path/to/file \
       --prefix '#start' \
       --suffix '#end' \
       --text 'some\nblock of\ntext'

    # text from stdin
    __block some-id \
       --file /path/to/file \
       --text - << DONE
    here some block
    of text
    DONE


AUTHORS
-------
Steven Armstrong <steven-cdist--@--armstrong.cc>


COPYING
-------
Copyright \(C) 2013 Steven Armstrong. You can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.
