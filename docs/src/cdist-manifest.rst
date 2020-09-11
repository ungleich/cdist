Manifest
========

Description
-----------
Manifests are used to define which objects to create.
Objects are instances of **types**, like in object oriented programming languages.
An object is represented by the combination of
**type + slash + object name**: **\__file/etc/cdist-configured** is an
object of the type **__file** with the name **etc/cdist-configured**.

All available types can be found in the **cdist/conf/type/** directory,
use **ls cdist/conf/type** to get the list of available types. If you have
setup the MANPATH correctly, you can use **man cdist-reference** to access
the reference with pointers to the manpages.


Types in manifests are used like normal command line tools. Let's have a look
at an example::

    # Create object of type __package with the parameter state = absent
    __package apache2 --state absent

    # Same with the __directory type
    __directory /tmp/cdist --state present

These two lines create objects, which will later be used to realise the 
configuration on the target host.

Manifests are executed locally as a shell script using **/bin/sh -e**.
The resulting objects are stored in an internal database.

The same object can be redefined in multiple different manifests as long as
the parameters are exactly the same.

In general, manifests are used to define which types are used depending
on given conditions.


Initial and type manifests
--------------------------
Cdist knows about two types of manifests: The initial manifest and type
manifests. The initial manifest is used to define, which configurations
to apply to which hosts. The type manifests are used to create objects
from types. More about manifests in types can be found in `cdist type <cdist-type.html>`_.


Define state in the initial manifest
------------------------------------
The **initial manifest** is the entry point for cdist to find out, which
**objects** to configure on the selected host.
Cdist expects the initial manifest at **cdist/conf/manifest/init**.

Within this initial manifest you define which objects should be
created on which host. To distinguish between hosts, you can use the
environment variable **__target_host** and/or **__target_hostname** and/or
**__target_fqdn**. Let's have a look at a simple example::

    __cdistmarker

    case "$__target_host" in
       localhost)
            __directory /home/services/kvm-vm --parents yes
       ;;
    esac

This manifest says: Independent of the host, always use the type 
**__cdistmarker**, which creates the file **/etc/cdist-configured**,
with the timestamp as content.
The directory **/home/services/kvm-vm**, including all parent directories, 
is only created on the host **localhost**.

As you can see, there is no magic involved, the manifest is simple shell code that
utilises cdist types. Every available type can be executed like a normal 
command.


Splitting up the initial manifest
---------------------------------
If you want to split up your initial manifest, you can create other shell
scripts in **cdist/conf/manifest/** and include them in **cdist/conf/manifest/init**.
Cdist provides the environment variable **__manifest** to reference
the directory containing the initial manifest (see `cdist reference <cdist-reference.html>`_).

The following example would include every file with a **.sh** suffix::

    # Include *.sh
    for manifest in $__manifest/*.sh; do
        # And source scripts into our shell environment
        . "$manifest"
    done


Dependencies
------------
If you want to describe that something requires something else, just
setup the variable "require" to contain the requirements. Multiple
requirements can be added separated with (optionally consecutive)
delimiters including space, tab and newline.

::

     1 # No dependency
     2 __file /etc/cdist-configured
     3 
     4 # Require above object
     5 require="__file/etc/cdist-configured" __link /tmp/cdist-testfile \
     6    --source /etc/cdist-configured  --type symbolic
     7 
     8 # Require two objects
     9 require="__file/etc/cdist-configured __link/tmp/cdist-testfile" \
    10    __file /tmp/cdist-another-testfile


Above the "require" variable is only set for the command that is 
immediately following it. Dependencies should always be declared that way.

On line 4 you can see that the instantiation of a type "\__link" object needs
the object "__file/etc/cdist-configured" to be present, before it can proceed.

This also means that the "\__link" command must make sure, that either
"\__file/etc/cdist-configured" already is present, or, if it's not, it needs
to be created. The task of cdist is to make sure, that the dependency will be
resolved appropriately and thus "\__file/etc/cdist-configured" be created
if necessary before "__link" proceeds (or to abort execution with an error).

If you really need to make all types depend on a common dependency, you can
export the "require" variable as well. But then, if you need to add extra
dependencies to a specific type, you have to make sure that you append these
to the globally already defined one.

::

    # First of all, update the package index
    __package_update_index
    # Upgrade all the installed packages afterwards
    require="__package_update_index" __package_upgrade_all
    # Create a common dependency for all the next types so that they get to
    # be executed only after the package upgrade has finished
    export require="__package_upgrade_all"

    # Ensure that lighttpd is installed after we have upgraded all the packages
    __package lighttpd --state present
    # Ensure that munin is installed after lighttpd is present and after all
    # the packages are upgraded
    require="$require __package/lighttpd" __package munin --state present


All objects that are created in a type manifest are automatically required
from the type that is calling them. This is called "autorequirement" in
cdist jargon.

You can find a more in depth description of the flow execution of manifests
in `cdist execution stages <cdist-stages.html>`_ and of how types work in `cdist type <cdist-type.html>`_.


Create dependencies from execution order
-----------------------------------------
You can tell cdist to execute all types in the order in which they are created 
in the manifest by setting up the variable CDIST_ORDER_DEPENDENCY.
When cdist sees that this variable is setup, the current created object
automatically depends on the previously created object.

It essentially helps you to build up blocks of code that build upon each other
(like first creating the directory xyz than the file below the directory).

Read also about `notes on CDIST_ORDER_DEPENDENCY <cdist-best-practice.html#notes-on-cdist-order-dependency>`_.

In version 6.2.0 semantic CDIST_ORDER_DEPENDENCY is finally fixed and well defined.

CDIST_ORDER_DEPENDENCY defines type order dependency context. Order dependency context
starts when CDIST_ORDER_DEPENDENCY is set, and ends when it is unset. After each
manifest execution finishes, any existing order dependency context is automatically
unset. This ensures that CDIST_ORDER_DEPENDENCY is valid within the manifest where it
is used. When order dependency context is defined then cdist executes types in the
order in which they are created in the manifest inside order dependency context.

Sometimes the best way to see how something works is to see examples.

Suppose you have defined **initial manifest**:

.. code-block:: sh

    __cycle1 cycle1
    export CDIST_ORDER_DEPENDENCY=1
    __cycle2 cycle2
    __cycle3 cycle3

with types **__cycle1**:

.. code-block:: sh

    export CDIST_ORDER_DEPENDENCY=1
    __file /tmp/cycle11
    __file /tmp/cycle12
    __file /tmp/cycle13

**__cycle2**:

.. code-block:: sh

    __file /tmp/cycle21
    export CDIST_ORDER_DEPENDENCY=1
    __file /tmp/cycle22
    __file /tmp/cycle23
    unset CDIST_ORDER_DEPENDENCY
    __file /tmp/cycle24

**__cycle3**:

.. code-block:: sh

    __file /tmp/cycle31
    __file /tmp/cycle32
    export CDIST_ORDER_DEPENDENCY=1
    __file /tmp/cycle33
    __file /tmp/cycle34

For the above config, cdist results in the following expected *dependency graph*
(type *__cycleX* is shown as *cX*, *__file/tmp/cycleXY* is shown as *fcXY*):

::

    c1---->fc11
    |      /\
    |       |
    +----->fc12
    |      /\
    |       |
    +----->fc13

    c2--+--->fc21
    /\  |
    |   |
    |   +----->fc22
    |   |      /\
    |   |       |
    |   +----->fc23
    |   |
    |   |
    |   +----->fc24
    |
    |
    c3---->fc31
    |
    |
    +----->fc32
    |
    |
    +----->fc33
    |      /\
    |       |
    +----->fc34

Before version 6.2.0 the above configuration would result in cycle:

::

    ERROR: 185.203.112.26: Cycle detected in object dependencies:
    __file/tmp/cycle11 -> __cycle3/cycle3 -> __cycle2/cycle2 -> __cycle1/cycle1 -> __file/tmp/cycle11!

The following manifest shows an example for order dependency contexts:

.. code-block:: sh

    __file /tmp/fileA
    export CDIST_ORDER_DEPENDENCY=1
    __file /tmp/fileB
    __file /tmp/fileC
    __file /tmp/fileD
    unset CDIST_ORDER_DEPENDENCY
    __file /tmp/fileE
    __file /tmp/fileF
    export CDIST_ORDER_DEPENDENCY=1
    __file /tmp/fileG
    __file /tmp/fileH
    unset CDIST_ORDER_DEPENDENCY
    __file /tmp/fileI

This means:

* C depends on B
* D depends on C
* H depends on G

and there are no other dependencies from this manifest.


Overrides
---------
In some special cases, you would like to create an already defined object 
with different parameters. In normal situations this leads to an error in cdist.
If you wish, you can setup the environment variable CDIST_OVERRIDE
(any value or even empty is ok) to tell cdist, that this object override is 
wanted and should be accepted.
ATTENTION: Only use this feature if you are 100% sure in which order 
cdist encounters the affected objects, otherwise this results
in an undefined situation. 

If CDIST_OVERRIDE and CDIST_ORDER_DEPENDENCY are set for an object,
CDIST_ORDER_DEPENDENCY will be ignored, because adding a dependency in case of
overrides would result in circular dependencies, which is an error.


Examples
--------
The initial manifest may for instance contain the following code:

.. code-block:: sh

    # Always create this file, so other sysadmins know cdist is used.
    __file /etc/cdist-configured

    case "$__target_host" in
       my.server.name)
          __directory /root/bin/
          __file /etc/issue.net --source "$__manifest/issue.net
       ;;
    esac

The manifest of the type "nologin" may look like this:

.. code-block:: sh

    __file /etc/nologin --source "$__type/files/default.nologin"

This example makes use of dependencies:

.. code-block:: sh

    # Ensure that lighttpd is installed
    __package lighttpd --state present
    # Ensure that munin makes use of lighttpd instead of the default webserver
    # package as decided by the package manager
    require="__package/lighttpd" __package munin --state present

How to override objects:

.. code-block:: sh

    # for example in the initial manifest

    # create user account foobar with some hash for password
    __user foobar --password 'some_fancy_hash' --home /home/foobarexample

    # ... many statements and includes in the manifest later ...
    # somewhere in a conditionally sourced manifest
    # (e.g. for example only sourced if a special application is on the target host)

    # this leads to an error ...
    __user foobar --password 'some_other_hash' 

    # this tells cdist, that you know that this is an override and should be accepted
    CDIST_OVERRIDE=yes __user foobar --password 'some_other_hash'
    # it's only an override, means the parameter --home is not touched 
    # and stays at the original value of /home/foobarexample

Dependencies defined by execution order work as following:

.. code-block:: sh

    # Tells cdist to execute all types in the order in which they are created ...
    export CDIST_ORDER_DEPENDENCY=on
    __sample_type 1
    require="__some_type_somewhere/id" __sample_type 2
    __example_type 23
    # Now this types are executed in the creation order until the variable is unset
    unset CDIST_ORDER_DEPENDENCY
    # all now following types cdist makes the order ..
    __not_in_order_type 42

    # how it works :
    # this lines above are translated to:
    __sample_type 1
    require="__some_type_somewhere/id __sample_type/1" __sample_type 2
    require="__sample_type/2" __example_type 23
    __not_in_order_type 42
