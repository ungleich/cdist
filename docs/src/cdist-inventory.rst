Inventory
=========

Introduction
------------

cdist comes with simple built-in tag based inventory. It is a simple inventory
with list of hosts and a host has a list of tags.
Inventory functionality is still in **beta** so it comes with new features
policy. New features are from now added with **beta** prefix. **beta\***
can change at any time without warning or might even be removed.

Description
-----------

The idea is to have simple tagging inventory. There is a list of hosts and for
each host there are tags. Inventory database is a set of files under inventory
database base directory. Filename equals hostname. Each file contains tags for
hostname with each tag on its own line.

Using inventory you can now configure hosts by selecting them by tags.

Tags have no values, as tags are just tags. Tag name-value would in this
context mean that host has two tags and it is selected by specifying that both
tags are present.

This inventory is **KISS** cdist built-in inventory database. You can maintain it
using cdist inventory interface or using standard UNIX tools.

cdist inventory interface
-------------------------

With cdist inventory interface you can list host(s) and tag(s), add host(s),
add tag(s), delete host(s) and delete tag(s).

Configuring hosts using inventory
---------------------------------

config command now has new options, **-t** and **-a**.

**-t** means that host specifies tag - all hosts that have specified tags are
selected.

**-a** means that selected hosts must contain ALL specified tags.

Examples
--------

.. code-block:: sh

    # List inventory content
    $ cdist betainventory list

    # List inventory for specified host localhost
    $ cdist betainventory list localhost

    # List inventory for specified tag loadbalancer
    $ cdist betainventory list -t loadbalancer

    # Add hosts to inventory
    $ cdist betainventory add-host web1 web2 web3

    # Delete hosts from file old-hosts from inventory
    $ cdist betainventory del-host -f old-hosts

    # Add tags to specifed hosts
    $ cdist betainventory add-tag -t europe,croatia,web,static web1 web2

    # Add tag to all hosts in inventory
    $ cdist betainventory add-tag -t vm

    # Delete all tags from specified host
    $ cdist betainventory del-tag -a localhost

    # Delete tags read from stdin from hosts specified by file hosts
    $ cdist betainventory del-tag -T - -f hosts

    # Configure hosts from inventory with any of specified tags
    $ cdist config -t web dynamic

    # Configure hosts from inventory with all specified tags
    $ cdist config -t -a web dynamic

Example of manipulating database
--------------------------------

.. code-block:: sh

    $ python3 scripts/cdist betainventory list
    $ python3 scripts/cdist betainventory add-host localhost
    $ python3 scripts/cdist betainventory add-host test.mycloud.net
    $ python3 scripts/cdist betainventory list
    localhost
    test.mycloud.net
    $ python3 scripts/cdist betainventory add-host web1.mycloud.net web2.mycloud.net shell1.mycloud.net shell2.mycloud.net
    $ python3 scripts/cdist betainventory list
    localhost
    test.mycloud.net
    web1.mycloud.net
    web2.mycloud.net
    shell1.mycloud.net
    shell2.mycloud.net
    $ python3 scripts/cdist betainventory add-tag -t web web1.mycloud.net web2.mycloud.net
    $ python3 scripts/cdist betainventory add-tag -t shell shell1.mycloud.net shell2.mycloud.net
    $ python3 scripts/cdist betainventory add-tag -t cloud
    $ python3 scripts/cdist betainventory list
    localhost cloud
    test.mycloud.net cloud
    web1.mycloud.net cloud,web
    web2.mycloud.net cloud,web
    shell1.mycloud.net cloud,shell
    shell2.mycloud.net cloud,shell
    $ python3 scripts/cdist betainventory add-tag -t test,web,shell test.mycloud.net
    $ python3 scripts/cdist betainventory list
    localhost cloud
    test.mycloud.net cloud,shell,test,web
    web1.mycloud.net cloud,web
    web2.mycloud.net cloud,web
    shell1.mycloud.net cloud,shell
    shell2.mycloud.net cloud,shell
    $ python3 scripts/cdist betainventory del-tag -t shell test.mycloud.net
    $ python3 scripts/cdist betainventory list
    localhost cloud
    test.mycloud.net cloud,test,web
    web1.mycloud.net cloud,web
    web2.mycloud.net cloud,web
    shell1.mycloud.net cloud,shell
    shell2.mycloud.net cloud,shell
    $ python3 scripts/cdist betainventory add-tag -t all
    $ python3 scripts/cdist betainventory add-tag -t mistake
    $ python3 scripts/cdist betainventory list
    localhost all,cloud,mistake
    test.mycloud.net all,cloud,mistake,test,web
    web1.mycloud.net all,cloud,mistake,web
    web2.mycloud.net all,cloud,mistake,web
    shell1.mycloud.net all,cloud,mistake,shell
    shell2.mycloud.net all,cloud,mistake,shell
    $ python3 scripts/cdist betainventory del-tag -t mistake
    $ python3 scripts/cdist betainventory list
    localhost all,cloud
    test.mycloud.net all,cloud,test,web
    web1.mycloud.net all,cloud,web
    web2.mycloud.net all,cloud,web
    shell1.mycloud.net all,cloud,shell
    shell2.mycloud.net all,cloud,shell
    $ python3 scripts/cdist betainventory del-host localhost
    $ python3 scripts/cdist betainventory list
    test.mycloud.net all,cloud,test,web
    web1.mycloud.net all,cloud,web
    web2.mycloud.net all,cloud,web
    shell1.mycloud.net all,cloud,shell
    shell2.mycloud.net all,cloud,shell
    $ python3 scripts/cdist betainventory list -t web
    test.mycloud.net all,cloud,test,web
    web1.mycloud.net all,cloud,web
    web2.mycloud.net all,cloud,web
    $ python3 scripts/cdist betainventory list -t -a web test
    test.mycloud.net all,cloud,test,web
    $ python3 scripts/cdist betainventory list -t -a web all
    test.mycloud.net all,cloud,test,web
    web1.mycloud.net all,cloud,web
    web2.mycloud.net all,cloud,web
    $ python3 scripts/cdist betainventory list -t web all
    test.mycloud.net all,cloud,test,web
    web1.mycloud.net all,cloud,web
    web2.mycloud.net all,cloud,web
    shell1.mycloud.net all,cloud,shell
    shell2.mycloud.net all,cloud,shell
    $ cd cdist/inventory
    $ ls -1
    shell1.mycloud.net
    shell2.mycloud.net
    test.mycloud.net
    web1.mycloud.net
    web2.mycloud.net
    $ ls -l
    total 20
    -rw-r--r--  1 darko  darko  16 Jun 24 12:43 shell1.mycloud.net
    -rw-r--r--  1 darko  darko  16 Jun 24 12:43 shell2.mycloud.net
    -rw-r--r--  1 darko  darko  19 Jun 24 12:43 test.mycloud.net
    -rw-r--r--  1 darko  darko  14 Jun 24 12:43 web1.mycloud.net
    -rw-r--r--  1 darko  darko  14 Jun 24 12:43 web2.mycloud.net
    $ cat test.mycloud.net
    test
    all
    web
    cloud
    $ cat web2.mycloud.net
    all
    web
    cloud

For more info about inventory commands and options see `cdist <man1/cdist.html>`_\ (1).

Using external inventory
------------------------

cdist can be used with any external inventory where external inventory is
some storage or database from which you can get a list of hosts to configure.
cdist can then be fed with this list of hosts through stdin or file using
**-f** option. For example, if your host list is stored in sqlite3 database
hosts.db and you want to select hosts which purpose is **django** then you
can use it with cdist like:

.. code-block:: sh

    $ sqlite3 hosts.db "select hostname from hosts where purpose = 'django';" | cdist config
