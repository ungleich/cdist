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
        try:
            with open(self.path, 'w') as fd:
                for line in lines:
                    fd.write(str(line) + '\n')
        except EnvironmentError as e:
            # should never happen
            raise cdist.Error(str(e))

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


class DirectoryDict(collections.MutableMapping):
    """A dict that stores it's items as files in a directory.

    """
    def __init__(self, path, initial=None, **kwargs):
        if not os.path.isabs(path):
            raise AbsolutePathRequiredError(path)
        self.path = path
        try:
            # create directory if it doesn't exist
            if not os.path.isdir(self.path):
                os.mkdir(self.path)
        except EnvironmentError as e:
            raise cdist.Error(str(e))
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
        try:
            with open(os.path.join(self.path, key), "w") as fd:
                if (not hasattr(value, 'strip') and
                    (hasattr(value, '__getitem__') or
                     hasattr(value, '__iter__'))):
                    # if it looks like a sequence and quacks like a sequence,
                    # it is a sequence
                    for v in value:
                        fd.write(str(v) + '\n')
                else:
                    fd.write(str(value))
                    # ensure file ends with a single newline
                    if value and value[-1] != '\n':
                        fd.write('\n')
        except EnvironmentError as e:
            raise cdist.Error(str(e))

    def __delitem__(self, key):
        try:
            os.remove(os.path.join(self.path, key))
        except EnvironmentError:
            raise KeyError(key)

    def __iter__(self):
        try:
            return iter(os.listdir(self.path))
        except EnvironmentError as e:
            raise cdist.Error(str(e))

    def __len__(self):
        try:
            return len(os.listdir(self.path))
        except EnvironmentError as e:
            raise cdist.Error(str(e))


class FileBasedProperty(object):
    attribute_class = None

    def __init__(self, path):
        """
        :param path: string or callable

        Abstract super class. Subclass and set the class member
        attribute_class accordingly.

        Usage with a sublcass:

        class Foo(object):
            # note that the actual DirectoryDict is stored as __parameters
            # on the instance
            parameters = DirectoryDictProperty(
                lambda instance: os.path.join(instance.absolute_path,
                                              'parameter'))
            # note that the actual DirectoryDict is stored as __other_dict
            # on the instance
            other_dict = DirectoryDictProperty('/tmp/other_dict')

            def __init__(self):
                self.absolute_path = '/tmp/foo'

        """
        self.path = path

    def _get_path(self, instance):
        path = self.path
        if callable(path):
            path = path(instance)
        return path

    def _get_property_name(self, owner):
        for name, prop in owner.__dict__.items():
            if self == prop:
                return name

    def _get_attribute(self, instance, owner):
        name = self._get_property_name(owner)
        attribute_name = '__%s' % name
        if not hasattr(instance, attribute_name):
            path = self._get_path(instance)
            attribute_instance = self.attribute_class(path)
            setattr(instance, attribute_name, attribute_instance)
        return getattr(instance, attribute_name)

    def __get__(self, instance, owner):
        if instance is None:
            return self
        return self._get_attribute(instance, owner)

    def __delete__(self, instance):
        raise AttributeError("can't delete attribute")


class DirectoryDictProperty(FileBasedProperty):
    attribute_class = DirectoryDict

    def __set__(self, instance, value):
        attribute_instance = self._get_attribute(instance, instance.__class__)
        for name in attribute_instance.keys():
            del attribute_instance[name]
        attribute_instance.update(value)


class FileListProperty(FileBasedProperty):
    attribute_class = FileList

    def __set__(self, instance, value):
        path = self._get_path(instance)
        try:
            os.unlink(path)
        except EnvironmentError:
            # ignored
            pass
        attribute_instance = self._get_attribute(instance, instance.__class__)
        for item in value:
            attribute_instance.append(item)


class FileBooleanProperty(FileBasedProperty):
    """A boolean property which uses a file to represent its value.

    File exists -> True
    File does not exists -> False
    """
    # Descriptor Protocol
    def __get__(self, instance, owner):
        if instance is None:
            return self
        path = self._get_path(instance)
        return os.path.isfile(path)

    def __set__(self, instance, value):
        path = self._get_path(instance)
        if value:
            try:
                open(path, "w").close()
            except EnvironmentError as e:
                raise cdist.Error(str(e))
        else:
            try:
                os.remove(path)
            except EnvironmentError:
                # ignore
                pass


class FileStringProperty(FileBasedProperty):
    """A string property which stores its value in a file.
    """
    # Descriptor Protocol
    def __get__(self, instance, owner):
        if instance is None:
            return self
        path = self._get_path(instance)
        value = ""
        try:
            with open(path, "r") as fd:
                value = fd.read().rstrip('\n')
        except EnvironmentError:
            pass
        return value

    def __set__(self, instance, value):
        path = self._get_path(instance)
        if value:
            try:
                with open(path, "w") as fd:
                    fd.write(str(value))
                    # ensure file ends with a single newline
                    if value[-1] != '\n':
                        fd.write('\n')
            except EnvironmentError as e:
                raise cdist.Error(str(e))
        else:
            try:
                os.remove(path)
            except EnvironmentError:
                pass
