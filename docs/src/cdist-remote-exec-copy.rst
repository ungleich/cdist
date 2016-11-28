Remote exec and copy commands
=============================

Cdist interacts with the target host in two ways:

- it executes code (__remote_exec)
- and it copies files (__remote_copy)

By default this is accomplished with ssh and scp respectively.
The default implementations used by cdist are::

    __remote_exec: ssh -o User=root
    __remote_copy: scp -o User=root

The user can override these defaults by providing custom implementations and
passing them to cdist with the --remote-exec and/or --remote-copy arguments.

For __remote_exec, the custom implementation must behave as if it where ssh.
For __remote_copy, it must behave like scp.
Please notice, custom implementations should work like ssh/scp so __remote_copy
must support IPv6 addresses enclosed in square brackets. For __remote_exec you
must take into account that for some options (like -L) IPv6 addresses can be
specified by enclosed in square brackets (see :strong:`ssh`\ (1) and
:strong:`scp`\ (1)).

With this simple interface the user can take total control of how cdist
interacts with the target when required, while the default implementation 
remains as simple as possible.
