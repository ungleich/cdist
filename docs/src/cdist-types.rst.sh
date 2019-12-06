#!/bin/sh
#
# 2019 Darko Poljak (darko.poljak at gmail.com) 
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
# Generate cdist-types.rst that lists available types.
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
cdist types
===========

.. toctree::
   :titlesonly:

eof

# If there is no such file then ls prints error to stderr,
# so redirect stderr to /dev/null.
for type in $(ls man7/cdist-type__*.rst 2>/dev/null | LC_ALL=C sort); do
    no_dir="${type#man7/}";
    no_type="${no_dir#cdist-type}";
    name="${no_type%.rst}";
    manref="${no_dir%.rst}"
    man="${manref}(7)"

    echo "   $name" "<man7/${manref}>"
done
