#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2016 Darko Poljak (darko.poljak at gmail.com)
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


def hostfile_process_line(line, strip_func=str.strip):
    """Return entry from read line or None if no entry present."""
    if not line:
        return None
    # remove comment if present
    comment_index = line.find('#')
    if comment_index >= 0:
        foo = line[:comment_index]
    else:
        foo = line
    # strip line
    foo = strip_func(foo)
    # skip empty lines
    if foo:
        return foo
    else:
        return None
