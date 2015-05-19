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
dest="$__cdist_abs_mydir/man7/$filename"

cd "$__cdist_abs_mydir"

exec > "$dest"
cat << eof 
cdist-reference(7)
==================
Nico Schottelius <nico-cdist--@--schottelius.org>

NAME
----
cdist-reference - Variable, path and type reference for cdist


EXPLORERS
---------
The following global explorers are available:

eof
(
    cd ../../cdist/conf/explorer
    for explorer in *; do
       echo "- $explorer"
    done
)

cat << eof 

PATHS
-----
\$HOME/.cdist::
    The standard cdist configuration directory relative to your home directory
    This is usually the place you want to store your site specific configuration

cdist/conf/::
    The distribution configuration directory
    This contains types and explorers to be used

confdir::
    Cdist will use all available configuration directories and create
    a temporary confdir containing links to the real configuration directories.
    This way it is possible to merge configuration directories.
    By default it consists of everything in \$HOME/.cdist and cdist/conf/.
    For more details see cdist(1)

confdir/manifest/init::
    This is the central entry point.
    It is an executable (+x bit set) shell script that can use
    values from the explorers to decide which configuration to create
    for the specified target host.
    Its intent is to used to define mapping from configurations to hosts.

confdir/manifest/*::
    All other files in this directory are not directly used by cdist, but you
    can separate configuration mappings, if you have a lot of code in the
    conf/manifest/init file. This may also be helpful to have different admins
    maintain different groups of hosts.

confdir/explorer/<name>::
    Contains explorers to be run on the target hosts, see cdist-explorer(7).

confdir/type/::
    Contains all available types, which are used to provide
    some kind of functionality. See cdist-type(7).

confdir/type/<name>/::
    Home of the type <name>.
    This directory is referenced by the variable __type (see below).

confdir/type/<name>/man.text::
    Manpage in Asciidoc format (required for inclusion into upstream)

confdir/type/<name>/manifest::
    Used to generate additional objects from a type.

confdir/type/<name>/gencode-local::
    Used to generate code to be executed on the source host

confdir/type/<name>/gencode-remote::
    Used to generate code to be executed on the target host

confdir/type/<name>/parameter/required::
    Parameters required by type, \n separated list.

confdir/type/<name>/parameter/optional::
    Parameters optionally accepted by type, \n separated list.

confdir/type/<name>/parameter/default/*::
    Default values for optional parameters.
    Assuming an optional parameter name of 'foo', it's default value would
    be read from the file confdir/type/<name>/parameter/default/foo.

confdir/type/<name>/parameter/boolean::
    Boolean parameters accepted by type, \n separated list.

confdir/type/<name>/explorer::
    Location of the type specific explorers.
    This directory is referenced by the variable __type_explorer (see below).
    See cdist-explorer(7).

confdir/type/<name>/files::
    This directory is reserved for user data and will not be used
    by cdist at any time. It can be used for storing supplementary
    files (like scripts to act as a template or configuration files).

out/::
    This directory contains output of cdist and is usually located
    in a temporary directory and thus will be removed after the run.
    This directory is referenced by the variable __global (see below).

out/explorer::
    Output of general explorers.

out/object::
    Objects created for the host.

out/object/<object>::
    Contains all object specific information.
    This directory is referenced by the variable __object (see below).

out/object/<object>/explorers::
    Output of type specific explorers, per object.

TYPES
-----
The following types are available:

eof

for type in man7/cdist-type__*.text; do
    no_dir="${type#man7/}";
    no_type="${no_dir#cdist-type}";
    name="${no_type%.text}";
    name_no_underline="$(echo $name | sed 's/^__/\\__/g')"
    man="${no_dir%.text}(7)"

    echo "- $name_no_underline" "($man)"
done

cat << eof


OBJECTS
-------
For object to object communication and tests, the following paths are
usable within a object directory:

files::
    This directory is reserved for user data and will not be used
    by cdist at any time. It can be used freely by the type 
    (for instance to store template results).
changed::
    This empty file exists in an object directory, if the object has
    code to be excuted (either remote or local)
stdin::
    This file exists and contains data, if data was provided on stdin 
    when the type was called.


ENVIRONMENT VARIABLES (FOR READING)
-----------------------------------
The following environment variables are exported by cdist:

__explorer::
    Directory that contains all global explorers.
    Available for: initial manifest, explorer, type explorer, shell
__manifest::
    Directory that contains the initial manifest.
    Available for: initial manifest, type manifest, shell
__global::
    Directory that contains generic output like explorer.
    Available for: initial manifest, type manifest, type gencode, shell
__messages_in::
    File to read messages from.
    Available for: initial manifest, type manifest, type gencode
__messages_out::
    File to write messages.
    Available for: initial manifest, type manifest, type gencode
__object::
    Directory that contains the current object.
    Available for: type manifest, type explorer, type gencode and code scripts
__object_id::
    The type unique object id.
    Available for: type manifest, type explorer, type gencode and code scripts
    Note: The leading and the trailing "/" will always be stripped (caused by
    the filesystem database and ensured by the core).
    Note: Double slashes ("//") will not be fixed and result in an error.
__object_name::
    The full qualified name of the current object.
    Available for: type manifest, type explorer, type gencode
__target_host::
    The host we are deploying to.
    Available for: explorer, initial manifest, type explorer, type manifest, type gencode, shell
__type::
    Path to the current type.
    Available for: type manifest, type gencode
__type_explorer::
    Directory that contains the type explorers.
    Available for: type explorer

ENVIRONMENT VARIABLES (FOR WRITING)
-----------------------------------
The following environment variables influence the behaviour of cdist:

require::
    Setup dependencies between objects (see cdist-manifest(7))

CDIST_LOCAL_SHELL::
    Use this shell locally instead of /bin/sh to execute scripts

CDIST_REMOTE_SHELL::
    Use this shell remotely instead of /bin/sh to execute scripts

CDIST_OVERRIDE::
    Allow overwriting type parameters (see cdist-manifest(7))

CDIST_ORDER_DEPENDENCY::
    Create dependencies based on the execution order (see cdist-manifest(7))

SEE ALSO
--------
- cdist(1)


COPYING
-------
Copyright \(C) 2011-2014 Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).
eof
