# -*- coding: utf-8 -*-
#
# 2010-2011 Steven Armstrong (steven-cdist at armstrong.cc)
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

import os
import collections

import cdist


class FileList(collections.MutableSequence):
    """A list that stores it's state in a file.

    """
    def __init__(self, path, initial=None):
        self._path = path
        if initial:
            for i in initial:
                self.append(i)

    def __read(self):
        lines = []
        try:
            with open(self._path) as fd:
                for line in fd:
                    lines.append(line.strip())
        except EnvironmentError as e:
            # error ignored
            pass
        return lines

    def __write(self, lines):
        try:
            with open(self._path, 'w') as fd:
                for line in lines:
                    fd.write(line + '\n')
        except EnvironmentError as e:
            # error ignored
            raise

    def __repr__(self):
        return repr(list(self))

    def __getitem__(self, index):
        return self.__read()[index]
        
    def __setitem__(self, index, value):
        lines = self.__read()
        lines[index] = value
        self.__write(lines)

    def __delitem__(self, index):
        lines = self.__read()
        del lines[index]
        self.__write(lines)

    def __len__(self):
        lines = self.__read()
        return len(lines)

    def insert(self, index, value):
        lines = self.__read()
        lines.insert(index, value)
        self.__write(lines)


class DirectoryDict(collections.MutableMapping):
    """A dict that stores it's state in a directory.

    """
    def __init__(self, path, dict=None, **kwargs):
        self._path = path
        if dict is not None:
            self.update(dict)
        if len(kwargs):
            self.update(kwargs)

    def __repr__(self):
        return repr(dict(self))

    def __getitem__(self, key):
        try:
            with open(os.path.join(self._path, key), "r") as fd:
                return fd.read()
        except EnvironmentError:
            raise KeyError(key)

    def __setitem__(self, key, value):
        with open(os.path.join(self._path, key), "w") as fd:
            fd.write(value)        

    def __delitem__(self, key):
        os.remove(os.path.join(self._path, key))

    def __iter__(self):
        return iter(os.listdir(self._path))

    def __len__(self):
        return len(os.listdir(self._path))
