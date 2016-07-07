Remote exec and copy commands
=============================

Cdist interacts with the target host in two ways:

- it executes code (__remote_exec)
- and it copies files (__remote_copy)

By default this is accomplished with ssh and scp respectively.
The default implementations used by cdist are::

    __remote_exec: ssh -o User=root -q
    __remote_copy: scp -o User=root -q

The user can override these defaults by providing custom implementations and
passing them to cdist with the --remote-exec and/or --remote-copy arguments.

For __remote_exec, the custom implementation must behave as if it where ssh.
For __remote_copy, it must behave like scp.

With this simple interface the user can take total control of how cdist
interacts with the target when required, while the default implementation 
remains as simple as possible.
