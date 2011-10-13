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


class AbsolutePathRequiredError(cdist.Error):
    def __init__(self, path):
        self.path = path

    def __str__(self):
        return 'Absolute path required, got: %s' % self.path


class FileList(collections.MutableSequence):
    """A list that stores it's state in a file.

    """
    def __init__(self, path, initial=None):
        if not os.path.isabs(path):
            raise AbsolutePathRequiredError(path)
        self.path = path
        if initial:
            # delete existing file
            try:
                os.unlink(self.path)
            except EnvironmentError:
                # ignored
                pass
            for i in initial:
                self.append(i)

    def __read(self):
        lines = []
        # if file does not exist return empty list
        try:
            with open(self.path) as fd:
                for line in fd:
                    lines.append(line.rstrip('\n'))
        except EnvironmentError as e:
            # error ignored
            pass
        return lines

    def __write(self, lines):
        with open(self.path, 'w') as fd:
            for line in lines:
                fd.write(str(line) + '\n')

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

    def sort(self):
        lines = sorted(self)
        self.__write(lines)


class FileListProperty(FileList):

    def __init__(self, path):
        """
        :param path: string or callable

        Usage:

        class Foo(object):
            parameters = DirectoryDictProperty(lambda obj: os.path.join(obj.absolute_path, 'parameter'))
            other_dict = DirectoryDictProperty('/tmp/folder')

            def __init__(self):
                self.absolute_path = '/tmp/foo'

        """
        self.path = None
        self.__path = path

    def _set_path(self, *args, **kwargs):
        if self.path is None:
            path = self.__path
            if callable(path):
                path = path(*args, **kwargs)
            if not os.path.isabs(path):
                raise AbsolutePathRequiredError(path)
            self.path = path

    # Descriptor Protocol
    def __get__(self, obj, objtype=None):
        if obj is None:
            return self.__class__
        self._set_path(obj)
        return self

    def __set__(self, obj, value):
        self._set_path(obj)
        try:
            os.unlink(self.path)
        except EnvironmentError:
            # ignored
            pass
        for item in value:
            self.append(item)

    def __delete__(self, obj):
        raise AttributeError("can't delete attribute")


class DirectoryDict(collections.MutableMapping):
    """A dict that stores it's items as files in a directory.

    """
    def __init__(self, path, initial=None, **kwargs):
        if not os.path.isabs(path):
            raise AbsolutePathRequiredError(path)
        self.path = path
        # create directory if it doesn't exist
        if not os.path.isdir(self.path):
            os.mkdir(self.path)
        if initial is not None:
            self.update(initial)
        if kwargs:
            self.update(kwargs)

    def __repr__(self):
        return repr(dict(self))

    def __getitem__(self, key):
        try:
            with open(os.path.join(self.path, key), "r") as fd:
                return fd.read().rstrip('\n')
        except EnvironmentError:
            raise KeyError(key)

    def __setitem__(self, key, value):
        with open(os.path.join(self.path, key), "w") as fd:
            fd.write(str(value))        

    def __delitem__(self, key):
        os.remove(os.path.join(self.path, key))

    def __iter__(self):
        return iter(os.listdir(self.path))

    def __len__(self):
        return len(os.listdir(self.path))


class DirectoryDictProperty(DirectoryDict):

    def __init__(self, path):
        """
        :param path: string or callable

        Usage:

        class Foo(object):
            parameters = DirectoryDictProperty(lambda obj: os.path.join(obj.absolute_path, 'parameter'))
            other_dict = DirectoryDictProperty('/tmp/folder')

            def __init__(self):
                self.absolute_path = '/tmp/foo'

        """
        self.path = None
        self.__path = path

    def _set_path(self, *args, **kwargs):
        print("_set_path: self=%r, args=%r, kwargs=%r" % (self, args, kwargs))
        if self.path is None:
            path = self.__path
            if callable(path):
                path = path(*args, **kwargs)
            print("_set_path: %s" % path)
            if not os.path.isabs(path):
                raise AbsolutePathRequiredError(path)
            # create directory if it doesn't exist
            print("os.path.isdir(%s): %s" % (path, os.path.isdir(path)))
            if not os.path.isdir(path):
                os.mkdir(path)
            self.path = path

    # Descriptor Protocol
    def __get__(self, obj, objtype=None):
        if obj is None:
            return self.__class__
        self._set_path(obj)
        return self

    def __set__(self, obj, value):
        self._set_path(obj)
        if value is not None:
            for name in self.keys():
                del self[name]
            self.update(value)

    def __delete__(self, obj):
        raise AttributeError("can't delete attribute")


class FileBooleanProperty(object):
    def __init__(self, path):
        """
        :param path: string or callable

        Usage:

        class Foo(object):
            changed = FileBoolean(lambda obj: os.path.join(obj.absolute_path, 'changed'))
            other_boolean = FileBoolean('/tmp/other_boolean')

            def __init__(self):
                self.absolute_path = '/tmp/foo_boolean'

        """
        self._path = path

    def _get_path(self, *args, **kwargs):
        path = self._path
        if callable(path):
            return path(*args, **kwargs)
        if not os.path.isabs(path):
            raise AbsolutePathRequiredError(path)
        return path

    # Descriptor Protocol
    def __get__(self, obj, objtype=None):
        if obj is None:
            return self.__class__
        path = self._get_path(obj)
        return os.path.isfile(path)

    def __set__(self, obj, value):
        path = self._get_path(obj)
        if value:
            open(path, "w").close()
        else:
            try:
                os.remove(path)
            except EnvironmentError:
                # ignore
                pass

    def __delete__(self, obj):
        raise AttributeError("can't delete attribute")


class FileStringProperty(object):
    """A string property which stores its value in a file.
    """
    def __init__(self, path):
        """
        :param path: string or callable

        Usage:

        class Foo(object):
            source = FileStringProperty(lambda obj: os.path.join(obj.absolute_path, 'source'))
            other = FileStringProperty('/tmp/other')

            def __init__(self):
                self.absolute_path = '/tmp/foo_boolean'

        """
        self._path = path

    def _get_path(self, *args, **kwargs):
        path = self._path
        if callable(path):
            return path(*args, **kwargs)
        if not os.path.isabs(path):
            raise AbsolutePathRequiredError(path)
        return path

    # Descriptor Protocol
    def __get__(self, obj, objtype=None):
        if obj is None:
            return self.__class__
        path = self._get_path(obj)
        value = ""
        try:
            with open(path, "r") as fd:
                value = fd.read()
        except EnvironmentError:
            pass
        return value

    def __set__(self, obj, value):
        path = self._get_path(obj)
        if value:
            with open(path, "w") as fd:
                fd.write(str(value))
        else:
            try:
                os.unlink(path)
            except EnvironmentError:
                pass

    def __delete__(self, obj):
        raise AttributeError("Can't delete attribute. Set it's value to an empty string to remove the underlying file.")
