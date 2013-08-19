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

import cconfig
import cconfig.schema

import cdist


class NoSuchTypeError(cdist.Error):
    def __init__(self, type_path, type_absolute_path):
        self.type_path = type_path
        self.type_absolute_path = type_absolute_path

    def __str__(self):
        return "Type '%s' does not exist at %s" % (self.type_path, self.type_absolute_path)


class CdistType(cconfig.Cconfig):
    """Represents a cdist type.

    All interaction with types in cdist should be done through this class.
    Directly accessing an type through the file system from python code is
    a bug.

    """

    schema_decl = (
        # path, type, subschema
        #('explorer', cconfig.schema.ListDirCconfigType),
        ('explorer', 'listdir'),
        ('install', bool),
        ('parameter', dict, (
            ('required', list),
            ('required_multiple', list),
            ('optional', list),
            ('optional_multiple', list),
            ('boolean', list),
        )), 
        ('singleton', bool),
    )   

    def __init__(self, base_path, name):
        self.base_path = base_path
        self.name = name
        self.path = self.name
        self.absolute_path = os.path.join(self.base_path, self.path)
        if not os.path.isdir(self.absolute_path):
            raise NoSuchTypeError(self.path, self.absolute_path)
        self.manifest_path = os.path.join(self.name, "manifest")
        self.explorer_path = os.path.join(self.name, "explorer")
        self.gencode_local_path = os.path.join(self.name, "gencode-local")
        self.gencode_remote_path = os.path.join(self.name, "gencode-remote")
        self.manifest_path = os.path.join(self.name, "manifest")

        super(CdistType, self).__init__(cconfig.Schema(self.schema_decl))
        self.from_dir(self.absolute_path)

    @property
    def explorer(self):
        return self['explorer']

    @property
    def parameter(self):
        return self['parameter']

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
        if not name in cls._instances:
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
        return self['singleton']

    @property
    def is_install(self):
        """Check whether a type is used for installation (if not: for configuration)"""
        return self['install']

    @property
    def explorers(self):
        """Return a list of available explorers"""
        return self['explorer']

    @property
    def required_parameters(self):
        """Return a list of required parameters"""
        return self['parameter']['required']

    @property
    def required_multiple_parameters(self):
        """Return a list of required multiple parameters"""
        return self['parameter']['required_multiple']

    @property
    def optional_parameters(self):
        """Return a list of optional parameters"""
        return self['parameter']['optional']

    @property
    def optional_multiple_parameters(self):
        """Return a list of optional multiple parameters"""
        return self['parameter']['optional_multiple']

    @property
    def boolean_parameters(self):
        """Return a list of boolean parameters"""
        return self['parameter']['boolean']
