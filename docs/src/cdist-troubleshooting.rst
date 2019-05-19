Troubleshooting
===============

Error in manifest is not considered an error by cdist
-----------------------------------------------------
Situation: You are executing other scripts from a manifest.
This script fails, but cdist does not recognise the error.
An example script would be something like this:

.. code-block:: sh

    % cat ~/.cdist/manifest/init
    "$__manifest/special"
    % cat ~/.cdist/manifest/special
    #!/bin/sh
    echo "Here is an unclean exiting script"
    somecommandthatdoesnotexist
    echo "I continue here although previous command failed"

We can clearly see that **somecommandthatdoesnotexist**
will fail in ~/.cdist/manifest/special. But as the custom
script is not called with the -e flag (exit on failure) of shell, 
it does not lead to an error. And thus cdist sees the exit 0
code of the last echo line instead of the failing command.

All scripts executed by cdist carry the -e flag. 
To prevent the above from happening, there are three solutions available,
two of which can be used in the calling script:

.. code-block:: sh

    # Execute as before, but abort on failure
    sh -e "$__manifest/special"

    # Source the script in our namespace, runs in a set -e environment:
    . "$__manifest/special"

The third solution is to include a shebang header in every script
you write to use the -e flag:

.. code-block:: sh

    % cat ~/.cdist/manifest/special
    #!/bin/sh -e
    ...

Using debug dump helper script
------------------------------
Since cdist stores data to local cache that can be used for debugging there
is a helper script that dumps data from local cache,
`cdist-dump <man1/cdist-dump.html>`_.

For more info see:

.. code-block:: sh

    cdist-dump -h

Or from cdist git cloned directory:

.. code-block:: sh

    ./scripts/cdist-dump -h

