#!/bin/sh
#
# 2010-2014 Nico Schottelius (nico-cdist at schottelius.org)
# 2014      Daniel Heule     (hda at sfs.biz)
#
# This file is part of cdist.
#
# cdist is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# cdist is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with cdist. If not, see <http://www.gnu.org/licenses/>.
#
#
# Generate manpage that lists available types
#

__cdist_pwd="$(pwd -P)"
__cdist_mydir="${0%/*}";
__cdist_abs_mydir="$(cd "$__cdist_mydir" && pwd -P)"
__cdist_myname=${0##*/};
__cdist_abs_myname="$__cdist_abs_mydir/$__cdist_myname"

filename="${__cdist_myname%.sh}"
dest="$__cdist_abs_mydir/$filename"

cd "$__cdist_abs_mydir"

exec > "$dest"
cat << eof
Reference
=========
Variable, path and type reference for cdist

Explorers
---------
The following global explorers are available:

eof
(
    cd ../../cdist/conf/explorer
    for explorer in $(ls * | LC_ALL=C sort); do
       echo "- $explorer"
    done
)

cat << eof

Paths
-----
\$HOME/.cdist
    The standard cdist configuration directory relative to your home directory.
    This is usually the place you want to store your site specific configuration.

cdist/conf/
    The distribution configuration directory.
    This contains types and explorers to be used.

cdist/inventory/
    The distribution inventory directory.
    This path is relative to cdist installation directory.

cdist/preos/
    The distribution PreOS plugins directory.

confdir
    Cdist will use all available configuration directories and create
    a temporary confdir containing links to the real configuration directories.
    This way it is possible to merge configuration directories.
    By default it consists of everything in \$HOME/.cdist and cdist/conf/.
    For more details see cdist(1).

confdir/files/
    Cdist does not care about this directory besides providing access to it.
    It is thought to be a general file storage area.

confdir/manifest/init
    This is the central entry point.
    It is an executable (+x bit set) shell script that can use
    values from the explorers to decide which configuration to create
    for the specified target host.
    Its intent is to used to define mapping from configurations to hosts.

confdir/manifest/*
    All other files in this directory are not directly used by cdist, but you
    can separate configuration mappings, if you have a lot of code in the
    conf/manifest/init file. This may also be helpful to have different admins
    maintain different groups of hosts.

confdir/explorer/<name>
    Contains explorers to be run on the target hosts, see \`cdist explorer <cdist-explorer.html>\`_.

confdir/type/
    Contains all available types, which are used to provide
    some kind of functionality. See \`cdist type <cdist-type.html>\`_.

confdir/type/<name>/
    Home of the type <name>.
    This directory is referenced by the variable __type (see below).

confdir/type/<name>/man.rst
    Manpage in reStructuredText format (required for inclusion into upstream).

confdir/type/<name>/manifest
    Used to generate additional objects from a type.

confdir/type/<name>/gencode-local
    Used to generate code to be executed on the source host.

confdir/type/<name>/gencode-remote
    Used to generate code to be executed on the target host.

confdir/type/<name>/parameter/required
    Parameters required by type, \n separated list.

confdir/type/<name>/parameter/optional
    Parameters optionally accepted by type, \n separated list.

confdir/type/<name>/parameter/default/*
    Default values for optional parameters.
    Assuming an optional parameter name of 'foo', it's default value would
    be read from the file confdir/type/<name>/parameter/default/foo.

confdir/type/<name>/parameter/boolean
    Boolean parameters accepted by type, \n separated list.

confdir/type/<name>/explorer
    Location of the type specific explorers.
    This directory is referenced by the variable __type_explorer (see below).
    See \`cdist explorer <cdist-explorer.html>\`_.

confdir/type/<name>/files
    This directory is reserved for user data and will not be used
    by cdist at any time. It can be used for storing supplementary
    files (like scripts to act as a template or configuration files).

out/
    This directory contains output of cdist and is usually located
    in a temporary directory and thus will be removed after the run.
    This directory is referenced by the variable __global (see below).

out/explorer
    Output of general explorers.

out/object
    Objects created for the host.

out/object/<object>
    Contains all object specific information.
    This directory is referenced by the variable __object (see below).

out/object/<object>/explorers
    Output of type specific explorers, per object.

Types
-----
The following types are available:

eof

# If there is no such file then ls prints error to stderr,
# so redirect stderr to /dev/null.
for type in $(ls man7/cdist-type__*.rst 2>/dev/null | LC_ALL=C sort); do
    no_dir="${type#man7/}";
    no_type="${no_dir#cdist-type}";
    name="${no_type%.rst}";
    manref="${no_dir%.rst}"
    man="${manref}(7)"

    echo "- $name" "(\`${man} <man7/${manref}.html>\`_)"
done

cat << eof


Objects
-------
For object to object communication and tests, the following paths are
usable within a object directory:

files
    This directory is reserved for user data and will not be used
    by cdist at any time. It can be used freely by the type
    (for instance to store template results).
changed
    This empty file exists in an object directory, if the object has
    code to be executed (either remote or local).
stdin
    This file exists and contains data, if data was provided on stdin
    when the type was called.


Environment variables (for reading)
-----------------------------------
The following environment variables are exported by cdist:

__cdist_log_level, __cdist_log_level_name
    cdist log level value and cdist log level name. One of:

    +----------------+-----------------+
    | Log level name | Log level value |
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

    Available for: initial manifest, explorer, type manifest, type explorer,
    type gencode.
__cdist_colored_log
    whether or not cdist's log has colors enabled.
    Is set to the string ``true`` if cdist's output is using colors,
    otherwise the variable contains the string ``false``.

    Available for: initial manifest, explorer, type manifest, type explorer,
    type gencode.
__cdist_dry_run
    Is set only when doing dry run (``-n`` flag).

    Available for: initial manifest, explorer, type manifest, type explorer,
    type gencode.
__explorer
    Directory that contains all global explorers.

    Available for: initial manifest, explorer, type explorer, shell.
__files
    Directory that contains content from the "files" subdirectories
    from the configuration directories.

    Available for: initial manifest, type manifest, type gencode, shell.
__manifest
    Directory that contains the initial manifest.

    Available for: initial manifest, type manifest, shell.
__global
    Directory that contains generic output like explorer.

    Available for: initial manifest, type manifest, type gencode, shell.
__messages_in
    File to read messages from.

    Available for: initial manifest, type manifest, type gencode.
__messages_out
    File to write messages.

    Available for: initial manifest, type manifest, type gencode.
__object
    Directory that contains the current object.

    Available for: type manifest, type explorer, type gencode and code scripts.
__object_id
    The type unique object id.

    Available for: type manifest, type explorer, type gencode and code scripts.

    | Note: The leading and the trailing "/" will always be stripped (caused by
      the filesystem database and ensured by the core).
    | Note: Double slashes ("//") will not be fixed and result in an error.
__object_name
    The full qualified name of the current object.

    Available for: type manifest, type explorer, type gencode.
__target_host
    The host we are deploying to. This is primary variable. It's content is
    literally the one user passed in.

    Available for: explorer, initial manifest, type explorer, type manifest, type gencode, shell.
__target_hostname
    The hostname of host we are deploying to. This variable is derived from
    **__target_host** (using **socket.getaddrinfo(__target_host)** and then
    **socket.gethostbyaddr()**).

    Available for: explorer, initial manifest, type explorer, type manifest, type gencode, shell.
__target_fqdn
    The fully qualified domain name of the host we are deploying to.
    This variable is derived from **__target_host**
    (using **socket.getfqdn()**).

    Available for: explorer, initial manifest, type explorer, type manifest, type gencode, shell.
__target_host_tags
    Comma separated list of target host tags.

    Available for: explorer, initial manifest, type explorer, type manifest, type gencode, shell.
__type
    Path to the current type.

    Available for: type manifest, type gencode.
__type_explorer
    Directory that contains the type explorers.

    Available for: type explorer.

Environment variables (for writing)
-----------------------------------
The following environment variables influence the behaviour of cdist:

require
    Setup dependencies between objects (see \`cdist manifest <cdist-manifest.html>\`_).

__cdist_log_level
    cdist log level value. One of:

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

    If set cdist will set this log level in
    accordance with configuration rules. If cdist invokation is used
    in types then nested cdist will honor this specified log level if
    not specified otherwise while invoking it.

CDIST_PATH
    Colon delimited list of config directories.

CDIST_LOCAL_SHELL
    Use this shell locally instead of /bin/sh to execute scripts.

CDIST_REMOTE_SHELL
    Use this shell remotely instead of /bin/sh to execute scripts.

CDIST_OVERRIDE
    Allow overwriting type parameters (see  \`cdist manifest <cdist-manifest.html>\`_).

CDIST_ORDER_DEPENDENCY
    Create dependencies based on the execution order (see  \`cdist manifest <cdist-manifest.html>\`_).
    Note that in version 6.2.0 semantic of this processing mode is finally fixed and well defined.

CDIST_REMOTE_EXEC
    Use this command for remote execution (should behave like ssh).

CDIST_REMOTE_COPY
    Use this command for remote copy (should behave like scp).

CDIST_INVENTORY_DIR
    Use this directory as inventory directory.

CDIST_BETA
    Enable beta functionalities.

CDIST_COLORED_OUTPUT
    Colorize cdist's output. If enabled, cdist will use different colors for
    different log levels.
    Recognized values are 'always', 'never', and 'auto' (the default).

CDIST_CACHE_PATH_PATTERN
    Custom cache path pattern.
eof
