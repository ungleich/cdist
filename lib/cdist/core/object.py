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


class Object(object):
    """Represents a cdist object.

    All interaction with objects in cdist should be done through this class.
    Directly accessing an object through the file system from python code is 
    a bug.

    """

    @staticmethod
    def base_dir():
        """Return the absolute path to the top level directory where objects
        are defined.

        Requires the environment variable '__cdist_out_dir' to be set.

        """
        try:
            base_dir = os.path.join(
                os.environ['__cdist_out_dir'],
                'object'
            )
        except KeyError as e:
            raise cdist.MissingEnvironmentVariableError(e.args[0])

        # FIXME: should directory be created elsewhere?
        if not os.path.isdir(base_dir):
            os.mkdir(base_dir)
        return base_dir

    @classmethod
    def list_objects(cls):
        """Return a list of object instances"""
        for object_name in cls.list_object_names():
            type_name = object_name.split(os.sep)[0]
            object_id = os.sep.join(object_name.split(os.sep)[1:])
            yield cls(Type(type_name), object_id=object_id)

    @classmethod
    def list_type_names(cls):
        """Return a list of type names"""
        return os.listdir(cls.base_dir())

    @classmethod
    def list_object_names(cls):
        """Return a list of object names"""
        for path, dirs, files in os.walk(cls.base_dir()):
            # FIXME: use constant instead of string
            if '.cdist' in dirs:
                yield os.path.relpath(path, cls.base_dir())

    def __init__(self, type, object_id=None, parameter=None, requirements=None):
        self.type = type # instance of Type
        self.object_id = object_id
        self.qualified_name = os.path.join(self.type.name, self.object_id)
        self.parameter = parameter or {}
        self.requirements = requirements or []
        
    def __repr__(self):
        return '<Object %s>' % self.qualified_name

    @property
    def path(self):
        return os.path.join(
            self.base_dir(),
            self.qualified_name,
            '.cdist'
        )

    @property
    def changed(self):
        """Check whether the object has been changed."""
        return os.path.isfile(os.path.join(self.path, "changed"))

    @changed.setter
    def changed(self, value):
        """Change the objects changed status."""
        path = os.path.join(self.path, "changed")
        if value:
            open(path, "w").close()
        else:
            try:
                os.remove(path)
            except EnvironmentError:
                # ignore
                pass

    # FIXME: implement other properties/methods
