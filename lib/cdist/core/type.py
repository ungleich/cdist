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

import cdist


class Type(object):

    @staticmethod
    def base_dir():
        """Return the absolute path to the top level directory where types
        are defined.

        Requires the environment variable '__cdist_base_dir' to be set.

        """
        try:
            return os.path.join(
                os.environ['__cdist_base_dir'],
                'conf',
                'type'
            )
        except KeyError as e:
            raise cdist.MissingEnvironmentVariableError(e.args[0])

    @classmethod
    def list_types(cls):
        """Return a list of type instances"""
        for type_name in cls.list_type_names():
            yield cls(type_name)

    @classmethod
    def list_type_names(cls):
        """Return a list of type names"""
        return os.listdir(cls.base_dir())


    def __init__(self, name):
        self.name = name
        self.__explorers = None
        self.__required_parameters = None
        self.__optional_parameters = None

    def __repr__(self):
        return '<Type name=%s>' % self.name

    @property
    def path(self):
        return os.path.join(
            self.base_dir(),
            self.name
        ) 

    @property
    def is_singleton(self):
        """Check whether a type is a singleton."""
        return os.path.isfile(os.path.join(self.path, "singleton"))

    @property
    def is_install(self):
        """Check whether a type is used for installation (if not: for configuration)"""
        return os.path.isfile(os.path.join(self.path, "install"))

    @property
    def explorers(self):
        """Return a list of available explorers"""
        if not self.__explorers:
            try:
                self.__explorers = os.listdir(os.path.join(self.path, "explorer"))
            except EnvironmentError as e:
                # error ignored
                self.__explorers = []
        return self.__explorers

    @property
    def required_parameters(self):
        """Return a list of required parameters"""
        if not self.__required_parameters:
            parameters = []
            try:
                with open(os.path.join(self.path, "parameter", "required")) as fd:
                    for line in fd:
                        parameters.append(line.strip())
            except EnvironmentError as e:
                # error ignored
                pass
            finally:
                self.__required_parameters = parameters
        return self.__required_parameters

    @property
    def optional_parameters(self):
        """Return a list of optional parameters"""
        if not self.__optional_parameters:
            parameters = []
            try:
                with open(os.path.join(self.path, "parameter", "optional")) as fd:
                    for line in fd:
                        parameters.append(line.strip())
            except EnvironmentError as e:
                # error ignored
                pass
            finally:
                self.__optional_parameters = parameters
        return self.__optional_parameters
