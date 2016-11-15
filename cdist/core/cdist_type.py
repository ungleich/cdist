# -*- coding: utf-8 -*-
#
# 2011 Steven Armstrong (steven-cdist at armstrong.cc)
# 2011 Nico Schottelius (nico-cdist at schottelius.org)
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

import cdist


class NoSuchTypeError(cdist.Error):
    def __init__(self, name, type_path, type_absolute_path):
        self.name = name
        self.type_path = type_path
        self.type_absolute_path = type_absolute_path

    def __str__(self):
        return "Type '%s' does not exist at %s" % (
                self.type_path, self.type_absolute_path)


class CdistType(object):
    """Represents a cdist type.

    All interaction with types in cdist should be done through this class.
    Directly accessing an type through the file system from python code is
    a bug.

    """

    def __init__(self, base_path, name):
        self.base_path = base_path
        self.name = name
        self.path = self.name
        self.absolute_path = os.path.join(self.base_path, self.path)
        if not os.path.isdir(self.absolute_path):
            raise NoSuchTypeError(self.name, self.path, self.absolute_path)
        self.manifest_path = os.path.join(self.name, "manifest")
        self.explorer_path = os.path.join(self.name, "explorer")
        self.gencode_local_path = os.path.join(self.name, "gencode-local")
        self.gencode_remote_path = os.path.join(self.name, "gencode-remote")
        self.manifest_path = os.path.join(self.name, "manifest")

        self.__explorers = None
        self.__required_parameters = None
        self.__required_multiple_parameters = None
        self.__optional_parameters = None
        self.__optional_multiple_parameters = None
        self.__boolean_parameters = None
        self.__parameter_defaults = None

    @classmethod
    def list_types(cls, base_path):
        """Return a list of type instances"""
        for name in cls.list_type_names(base_path):
            yield cls(base_path, name)

    @classmethod
    def list_type_names(cls, base_path):
        """Return a list of type names"""
        return os.listdir(base_path)

    _instances = {}

    def __new__(cls, *args, **kwargs):
        """only one instance of each named type may exist"""
        # name is second argument
        name = args[1]
        if name not in cls._instances:
            instance = super(CdistType, cls).__new__(cls)
            cls._instances[name] = instance
            # return instance so __init__ is called
        return cls._instances[name]

    def __repr__(self):
        return '<CdistType %s>' % self.name

    def __eq__(self, other):
        return isinstance(other, self.__class__) and self.name == other.name

    def __lt__(self, other):
        return isinstance(other, self.__class__) and self.name < other.name

    @property
    def is_singleton(self):
        """Check whether a type is a singleton."""
        return os.path.isfile(os.path.join(self.absolute_path, "singleton"))

    @property
    def is_install(self):
        """Check whether a type is used for installation
          (if not: for configuration)"""
        return os.path.isfile(os.path.join(self.absolute_path, "install"))

    @property
    def explorers(self):
        """Return a list of available explorers"""
        if not self.__explorers:
            try:
                self.__explorers = os.listdir(os.path.join(self.absolute_path,
                                                           "explorer"))
            except EnvironmentError:
                # error ignored
                self.__explorers = []
        return self.__explorers

    @property
    def required_parameters(self):
        """Return a list of required parameters"""
        if not self.__required_parameters:
            parameters = []
            try:
                with open(os.path.join(self.absolute_path,
                                       "parameter",
                                       "required")) as fd:
                    for line in fd:
                        parameters.append(line.strip())
            except EnvironmentError:
                # error ignored
                pass
            finally:
                self.__required_parameters = parameters
        return self.__required_parameters

    @property
    def required_multiple_parameters(self):
        """Return a list of required multiple parameters"""
        if not self.__required_multiple_parameters:
            parameters = []
            try:
                with open(os.path.join(self.absolute_path,
                                       "parameter",
                                       "required_multiple")) as fd:
                    for line in fd:
                        parameters.append(line.strip())
            except EnvironmentError:
                # error ignored
                pass
            finally:
                self.__required_multiple_parameters = parameters
        return self.__required_multiple_parameters

    @property
    def optional_parameters(self):
        """Return a list of optional parameters"""
        if not self.__optional_parameters:
            parameters = []
            try:
                with open(os.path.join(self.absolute_path,
                                       "parameter",
                                       "optional")) as fd:
                    for line in fd:
                        parameters.append(line.strip())
            except EnvironmentError:
                # error ignored
                pass
            finally:
                self.__optional_parameters = parameters
        return self.__optional_parameters

    @property
    def optional_multiple_parameters(self):
        """Return a list of optional multiple parameters"""
        if not self.__optional_multiple_parameters:
            parameters = []
            try:
                with open(os.path.join(self.absolute_path,
                                       "parameter",
                                       "optional_multiple")) as fd:
                    for line in fd:
                        parameters.append(line.strip())
            except EnvironmentError:
                # error ignored
                pass
            finally:
                self.__optional_multiple_parameters = parameters
        return self.__optional_multiple_parameters

    @property
    def boolean_parameters(self):
        """Return a list of boolean parameters"""
        if not self.__boolean_parameters:
            parameters = []
            try:
                with open(os.path.join(self.absolute_path,
                                       "parameter",
                                       "boolean")) as fd:
                    for line in fd:
                        parameters.append(line.strip())
            except EnvironmentError:
                # error ignored
                pass
            finally:
                self.__boolean_parameters = parameters
        return self.__boolean_parameters

    @property
    def parameter_defaults(self):
        if not self.__parameter_defaults:
            defaults = {}
            try:
                defaults_dir = os.path.join(self.absolute_path,
                                            "parameter",
                                            "default")
                for name in os.listdir(defaults_dir):
                    try:
                        with open(os.path.join(defaults_dir, name)) as fd:
                            defaults[name] = fd.read().strip()
                    except EnvironmentError:
                        pass  # Swallow errors raised by open() or read()
            except EnvironmentError:
                pass  # Swallow error raised by os.listdir()
            finally:
                self.__parameter_defaults = defaults
        return self.__parameter_defaults
