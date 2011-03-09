#!/bin/sh
#
# 2010-2011 Nico Schottelius (nico-cdist at schottelius.org)
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
cdist-type-listing(7)
=====================
Nico Schottelius <nico-cdist--@--schottelius.org>


NAME
----
cdist-type-listing - Available types in cdist


SYNOPSIS
--------
Types that are included in cdist $(git describe).


DESCRIPTION
-----------
The following types are available:

eof
for type in cdist-type__*.text; do
   name_1="${type#cdist-type}"
   name_2="${name_1%.text}"

   name="$name_2"
   echo "- $name"
done

cat << eof


SEE ALSO
--------
- cdist-type(7)
eof
for type in cdist-type__*.text; do
   name_2="${type%.text}"

   name="$name_2"
   echo "- ${name}(7)"
done

cat <<eof

COPYING
-------
Copyright \(C) 2011-$(date +%Y) Nico Schottelius. Free use of this software is
granted under the terms of the GNU General Public License version 3 (GPLv3).

eof
