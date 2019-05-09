Quickstart
==========

This tutorial is aimed at people learning cdist and shows
typical approaches as well as gives an easy start into
the world of configuration management.

For those who just want to configure a system with the
cdist configuration management and do not need (or want)
to understand everything.

This tutorial assumes you are configuring **localhost**, because
it is always available. Just replace **localhost** with your target
host for real life usage.

Cdist uses **ssh** for communication and transportation
and usually logs into the **target host** as the
**root** user. So you need to configure the **ssh server**
of the target host to allow root logins: Edit
the file **/etc/ssh/sshd_config** and add one of the following
lines::

    # Allow login only via public key
    PermitRootLogin without-password

    # Allow login via password and public key
    PermitRootLogin yes

As cdist uses ssh intensively, it is recommended to setup authentication
with public keys::

    # Generate pubkey pair as a normal user
    ssh-keygen

    # Copy pubkey over to target host
    ssh-copy-id root@localhost

Have a look at ssh-agent(1) and ssh-add(1) on how to cache the password for
your public key.  Usually it looks like this::

    # Start agent and export variables
    eval `ssh-agent`

    # Add keys (requires password for every identity file)
    ssh-add

At this point you should be able to **ssh root@localhost** without
re-entering the password. If something failed until here, ensure that
all steps went successfully and you have read and understood the
documentation.

As soon as you are able to login without password to localhost,
we can use cdist to configure it. You can copy and paste the following
code into your shell to get started and configure localhost::

    # Get cdist 
    git clone git@code.ungleich.ch:ungleich-public/cdist.git

    # Create manifest (maps configuration to host(s)
    cd cdist
    echo '__file /etc/cdist-configured' > cdist/conf/manifest/init

    # Configure localhost in verbose mode
    ./bin/cdist config -v localhost

    # Find out that cdist created /etc/cdist-configured
    ls -l /etc/cdist-configured

Note: cdist/conf is configuration directory shipped with cdist distribution.
If exists, ~/.cdist, is also automatically used as cdist configuration
directory. So in the above example you could create ~/.cdist directory,
then ~/.cdist/manifest sub-directory and create init manifest
~/.cdist/manifest/init.

That's it, you've successfully used cdist to configure your first host!
Continue reading the next sections, to understand what you did and how
to create a more sophisticated configuration.
