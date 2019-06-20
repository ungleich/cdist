cdist type
==========

Description
-----------
Types are the main component of cdist and define functionality. If you
use cdist, you'll write a type for every functionality you would like
to use.

Synopsis
--------

.. code-block:: sh

    __TYPE ID --parameter value [--parameter value ...]
    __TYPE --parameter value [--parameter value ...] (for singletons)


How to use a type
-----------------

You can use types from the initial manifest or the type manifest like a
normal shell command:

.. code-block:: sh

    # Creates empty file /etc/cdist-configured
    __file /etc/cdist-configured --type file

    # Ensure tree is installed
    __package tree --state installed

A list of supported types can be found in the `cdist reference <cdist-reference.html>`_ manpage.


Singleton types
---------------
If a type is flagged as a singleton, it may be used only
once per host. This is useful for types which can be used only once on a
system. Singleton types do not take an object name as argument.


Example:

.. code-block:: sh

    # __issue type manages /etc/issue
    __issue

    # Probably your own type - singletons may use parameters
    __myfancysingleton --colour green


Config types
------------
By default types are used with config command. These are types that are not
flagged by any known command flag. If a type is marked then it will be skipped
with config command.


Install types
-------------
If a type is flagged with 'install' flag then it is used only with install command.
With other commands, i.e. config, these types are skipped if used.


Nonparallel types
-----------------
If a type is flagged with 'nonparallel' flag then its objects cannot be run in parallel
when using -j option. Example of such a type is __package_dpkg type where dpkg itself
prevents to be run in more than one instance.


Deprecated types
-----------------
If a type is flagged with 'deprecated' marker then it is considered deprecated.
When it is used cdist writes warning line. If 'deprecated' marker has content
then this content is printed as a deprecation messages, e.g.:

.. code-block:: sh

    $ ls -l deprecated 
    -rw-r--r--  1 darko  darko  71 May 20 18:30 deprecated
    $ cat deprecated 
    This type is deprecated. It will be removed in the next minor release.
    $ echo '__foo foo' | ./bin/cdist config -i - 185.203.112.26
    WARNING: 185.203.112.26: Type __foo is deprecated: This type is deprecated. It will be removed in the next minor release.

If 'deprecated' marker has no content then general message is printed, e.g.:

.. code-block:: sh

    $ ls -l deprecated 
    -rw-r--r--  1 darko  darko  0 May 20 18:36 deprecated
    $ echo '__bar foo' | ./bin/cdist config -i - 185.203.112.26
    WARNING: 185.203.112.26: Type __bar is deprecated.


How to write a new type
-----------------------
A type consists of

- parameter    (optional)
- manifest     (optional)
- singleton    (optional)
- explorer     (optional)
- gencode      (optional)
- nonparallel  (optional)

Types are stored below cdist/conf/type/. Their name should always be prefixed with
two underscores (__) to prevent collisions with other executables in $PATH.

To implement a new type, create the directory **cdist/conf/type/__NAME**.

Type manifest and gencode can be written in any language. They just need to be
executable and have a proper shebang. If they are not executable then cdist assumes
they are written in shell so they are executed using '/bin/sh -e' or 'CDIST_LOCAL_SHELL'.

For executable shell code it is suggested that shebang is '#!/bin/sh -e'.

For creating type skeleton you can use helper script
`cdist-new-type <man1/cdist-new-type.html>`_.


Defining parameters
-------------------
Every type consists of required, optional and boolean parameters, which must
each be declared in a newline separated file in **parameter/required**,
**parameter/required_multiple**, **parameter/optional**, 
**parameter/optional_multiple** and **parameter/boolean**.
Parameters which are allowed multiple times should be listed in
required_multiple or optional_multiple respectively. All other parameters
follow the standard unix behaviour "the last given wins".
If either is missing, the type will have no required, no optional, no boolean
or no parameters at all. 

Default values for optional parameters can be predefined in
**parameter/default/<name>**.

Example:

.. code-block:: sh

    echo servername >> cdist/conf/type/__nginx_vhost/parameter/required
    echo logdirectory >> cdist/conf/type/__nginx_vhost/parameter/optional
    echo loglevel >> cdist/conf/type/__nginx_vhost/parameter/optional
    mkdir cdist/conf/type/__nginx_vhost/parameter/default
    echo warning > cdist/conf/type/__nginx_vhost/parameter/default/loglevel
    echo server_alias >> cdist/conf/type/__nginx_vhost/parameter/optional_multiple
    echo use_ssl >> cdist/conf/type/__nginx_vhost/parameter/boolean


Using parameters
----------------
The parameters given to a type can be accessed and used in all type scripts
(e.g manifest, gencode, explorer). Note that boolean parameters are
represented by file existence. File exists -> True,
file does not exist -> False

Example: (e.g. in cdist/conf/type/__nginx_vhost/manifest)

.. code-block:: sh

    # required parameter
    servername="$(cat "$__object/parameter/servername")"

    # optional parameter
    if [ -f "$__object/parameter/logdirectory" ]; then
       logdirectory="$(cat "$__object/parameter/logdirectory")"
    fi

    # optional parameter with predefined default
    loglevel="$(cat "$__object/parameter/loglevel")"

    # boolean parameter
    if [ -f "$__object/parameter/use_ssl" ]; then
       # file exists -> True
       # do some fancy ssl stuff
    fi

    # parameter with multiple values
    if [ -f "$__object/parameter/server_alias" ]; then
       for alias in $(cat "$__object/parameter/server_alias"); do
          echo $alias > /some/where/useful
       done
    fi


Deprecated parameters
---------------------
To deprecate type parameters one can declare a file for each deprecated
parameter under **parameter/deprecated** directory.

When such parameter is used cdist writes warning line with deprecation message.
If such file has content then this content is printed as deprecation message.
If there is no content then generic parameter deprecation message is printed.

Example:

.. code-block:: sh

    $ ls parameter/deprecated/
    eggs    spam
    $ cat parameter/deprecated/eggs
    eggs parameter is deprecated, please use multiple egg parameter.
    $ cat parameter/deprecated/spam
    $ echo '__foo foo --foo foo --eggs eggs' | ./bin/cdist config -i - 185.203.112.26
    WARNING: 185.203.112.26: eggs parameter of type __foo is deprecated: eggs parameter is deprecated, please use multiple egg parameter.
    $ echo '__foo foo --foo foo --eggs eggs --spam spam' | ./bin/cdist config -i - 185.203.112.26
    WARNING: 185.203.112.26: spam parameter of type __foo is deprecated.
    WARNING: 185.203.112.26: eggs parameter of type __foo is deprecated: eggs parameter is deprecated, please use multiple egg parameter.


Input from stdin
----------------
Every type can access what has been written on stdin when it has been called.
The result is saved into the **stdin** file in the object directory.

Example use of a type: (e.g. in cdist/conf/type/__archlinux_hostname)

.. code-block:: sh

    __file /etc/rc.conf --source - << eof
    ...
    HOSTNAME="$__target_host"
    ...
    eof

If you have not seen this syntax (<< eof) before, it may help you to read
about "here documents".

In the __file type, stdin is used as source for the file, if - is used for source:

.. code-block:: sh

    if [ -f "$__object/parameter/source" ]; then
        source="$(cat "$__object/parameter/source")"
        if [ "$source" = "-" ]; then
            source="$__object/stdin"
        fi  
    ....


Stdin inside a loop
~~~~~~~~~~~~~~~~~~~
Since cdist saves type's stdin content in the object as **$__object/stdin**,
so it can be accessed in manifest and gencode-* scripts, this can lead to
unexpected behavior. For example, suppose you have some type with the following
in its manifest:

.. code-block:: sh

    if [ -f "$__object/parameter/foo" ]
    then
        while read -r l
        do
            __file "$l"
            echo "$l" >&2
        done < "$__object/parameter/foo"
    fi

and init manifest:

.. code-block:: sh

    __foo foo --foo a --foo b --foo c

You expect that manifest stderr content is:

.. code-block:: sh

    a
    b
    c

and that files *a*, *b* and *c* are created. But all you get in manifest stderr
is:

.. code-block:: sh

    a

and only *a* file is created.

When redirecting parameter *foo* file content to while's stdin that means that all
commands in while body have this same stdin. So when *__file* type gets executed,
cdist saves its stdin which means it gets the remaining content of parameter *foo*
file, i.e.:

.. code-block:: sh

    b
    c

The solution is to make sure that your types inside such loops get their stdin
from somewhere else, e.g. for the above problem *__file* type can get empty
stdin from */dev/null*:

.. code-block:: sh

    if [ -f "$__object/parameter/foo" ]
    then
        while read -r l
        do
            __file "$l" < /dev/null
            echo "$l" >&2
        done < "$__object/parameter/foo"
    fi


Writing the manifest
--------------------
In the manifest of a type you can use other types, so your type extends
their functionality. A good example is the __package type, which in
a shortened version looks like this:

.. code-block:: sh

    os="$(cat "$__global/explorer/os")"
    case "$os" in
          archlinux) type="pacman" ;;
          debian|ubuntu) type="apt" ;;
          gentoo) type="emerge" ;;
          *)
             echo "Don't know how to manage packages on: $os" >&2
             exit 1
          ;;
    esac

    __package_$type "$@"

As you can see, the type can reference different environment variables,
which are documented in `cdist reference <cdist-reference.html>`_.

Always ensure the manifest is executable, otherwise cdist will not be able
to execute it. For more information about manifests see `cdist manifest <cdist-manifest.html>`_.


Singleton - one instance only
-----------------------------
If you want to ensure that a type can only be used once per target, you can
mark it as a singleton: Just create the (empty) file "singleton" in your type
directory:

.. code-block:: sh

    touch cdist/conf/type/__NAME/singleton

This will also change the way your type must be called:

.. code-block:: sh

    __YOURTYPE --parameter value

As you can see, the object ID is omitted, because it does not make any sense,
if your type can be used only once.


Install - type with install command
-----------------------------------
If you want a type to be used with install command, you must mark it as
install: create the (empty) file "install" in your type directory:

.. code-block:: sh

    touch cdist/conf/type/__install_NAME/install

With other commands, i.e. config, it will be skipped if used.


Nonparallel - only one instance can be run at a time
----------------------------------------------------
If objects of a type must not or cannot be run in parallel when using -j
option, you must mark it as nonparallel: create the (empty) file "nonparallel"
in your type directory:

.. code-block:: sh

    touch cdist/conf/type/__NAME/nonparallel

For example, package types are nonparallel types.


The type explorers
------------------
If a type needs to explore specific details, it can provide type specific
explorers, which will be executed on the target for every created object.

The explorers are stored under the "explorer" directory below the type.
It could for instance contain code to check the md5sum of a file on the
client, like this (shortened version from the type __file):

.. code-block:: sh

    if [ -f "$__object/parameter/destination" ]; then
       destination="$(cat "$__object/parameter/destination")"
    else
       destination="/$__object_id"
    fi

    if [ -e "$destination" ]; then
       md5sum < "$destination"
    fi


Writing the gencode script
--------------------------
There are two gencode scripts: **gencode-local** and **gencode-remote**.
The output of gencode-local is executed locally, whereas
the output of gencode-remote is executed on the target.
The gencode scripts can make use of the parameters, the global explorers
and the type specific explorers.

If the gencode scripts encounters an error, it should print diagnostic
messages to stderr and exit non-zero. If you need to debug the gencode
script, you can write to stderr:

.. code-block:: sh

    # Debug output to stderr
    echo "My fancy debug line" >&2

    # Output to be saved by cdist for execution on the target
    echo "touch /etc/cdist-configured"

Notice: if you use __remote_copy or __remote_exec directly in your scripts
then for IPv6 address with __remote_copy execution you should enclose IPv6
address in square brackets. The same applies to __remote_exec if it behaves
the same as ssh for some options where colon is a delimiter, as for -L ssh
option (see :strong:`ssh`\ (1) and :strong:`scp`\ (1)).


Variable access from the generated scripts
------------------------------------------
In the generated scripts, you have access to the following cdist variables

- __object
- __object_id

but only for read operations, means there is no back copy of this
files after the script execution.

So when you generate a script with the following content, it will work:

.. code-block:: sh

    if [ -f "$__object/parameter/name" ]; then
       name="$(cat "$__object/parameter/name")"
    else
       name="$__object_id"
    fi


Environment variable usage idiom
--------------------------------
In type scripts you can support environment variables with default values if
environment variable is unset or null by using **${parameter:-[word]}**
parameter expansion.

Example using mktemp in a portable way that supports TMPDIR environment variable.

.. code-block:: sh

    tempfile=$(mktemp "${TMPDIR:-/tmp}/cdist.XXXXXXXXXX")


Log level in types
------------------
cdist log level can be accessed from __cdist_log_level variable.One of:

    +----------------+-----------------+
    | Log level      | Log level value |
    +================+=================+
    | OFF            | 60              |
    +----------------+-----------------+
    | ERROR          | 40              |
    +----------------+-----------------+
    | WARNING        | 30              |
    +----------------+-----------------+
    | INFO           | 20              |
    +----------------+-----------------+
    | VERBOSE        | 15              |
    +----------------+-----------------+
    | DEBUG          | 10              |
    +----------------+-----------------+
    | TRACE          | 5               |
    +----------------+-----------------+


It is available for initial manifest, explorer, type manifest,
type explorer, type gencode.


Detecting dry run
-----------------

If ``$__cdist_dry_run`` environment variable is set, then it's dry run.

It is available for initial manifest, explorer, type manifest,
type explorer, type gencode.


Hints for typewriters
----------------------
It must be assumed that the target is pretty dumb and thus does not have high
level tools like ruby installed. If a type requires specific tools to be present
on the target, there must be another type that provides this tool and the first
type should create an object of the specific type.

If your type wants to save temporary data, that may be used by other types
later on (for instance \__file), you can save them in the subdirectory
"files" below $__object (but you must create it yourself).
cdist will not touch this directory.

If your type contains static files, it's also recommended to place them in
a folder named "files" within the type (again, because cdist guarantees to
never ever touch this folder).


How to include a type into upstream cdist
-----------------------------------------
If you think your type may be useful for others, ensure it works with the
current master branch of cdist and have a look at `cdist hacking <cdist-hacker.html>`_ on
how to submit it.
