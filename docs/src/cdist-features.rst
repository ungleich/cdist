Features
========

But cdist ticks differently, here is the feature set that makes it unique:

Simplicity
    There is only one type to extend cdist called **type**

Design
    + Type and core cleanly separated
    + Sticks completely to the KISS (keep it simple and stupid)  paradigm
    + Meaningful error messages - do not lose time debugging error messages
    + Consistency in behaviour, naming and documentation
    + No surprise factor: Only do what is obviously clear, no magic
    + Define target state, do not focus on methods or scripts
    + Push architecture: Instantly apply your changes

Small core
    cdist's core is very small - less code, less bugs

Fast development
    Focus on straightforwardness of type creation is a main development objective
    Batteries included: A lot of requirements can be solved using standard types

Modern Programming Language
    cdist is written in Python

Requirements, Scalability
    No central server needed, cdist operates in push mode and can be run from any computer

Requirements, Scalability, Upgrade
    cdist only needs to be updated on the master, not on the target hosts

Requirements, Security
    Uses well-know `SSH <http://www.openssh.com/>`_ as transport protocol

Requirements, Simplicity
    Requires only shell and SSH server on the target

UNIX
    Reuse of existing tools like cat, find, mv, ...

UNIX, familiar environment, documentation
    Is available as manpages and HTML

UNIX, simplicity, familiar environment
    cdist is configured in POSIX shell

