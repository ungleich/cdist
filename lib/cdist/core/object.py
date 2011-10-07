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

import logging
import os
import collections

import cdist
import cdist.core.property

log = logging.getLogger(__name__)

DOT_CDIST = '.cdist'


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
            yield cls(cdist.core.Type(type_name), object_id=object_id)

    @classmethod
    def list_type_names(cls):
        """Return a list of type names"""
        return os.listdir(cls.base_dir())

    @classmethod
    def list_object_names(cls):
        """Return a list of object names"""
        for path, dirs, files in os.walk(cls.base_dir()):
            # FIXME: use constant instead of string
            if DOT_CDIST in dirs:
                yield os.path.relpath(path, cls.base_dir())

    def __init__(self, type, object_id=None, parameters=None, requirements=None):
        self.type = type # instance of Type
        self.object_id = object_id
        self.name = os.path.join(self.type.name, self.object_id)
        self.parameters = parameters or {}
        self.requirements = requirements or []

        self.__parameters = None
        self.__requirements = None

        # Whether this object was prepared/ran
        self.prepared = False
        self.ran = False
        
    def __repr__(self):
        return '<Object %s>' % self.name

    @property
    def path(self):
        return os.path.join(
            self.base_dir(),
            self.name,
            DOT_CDIST
        )

    @property
    def code(self):
        return os.path.join(self.path, "code-local")

    @property
    def code_remote(self):
        return os.path.join(self.path, "code-remote")

    ### requirements
    @property
    def requirements(self):
        if not self.__requirements:
            self.__requirements = cdist.core.property.FileList(os.path.join(self.path, "require"))
        return self.__requirements

    @requirements.setter
    def requirements(self, value):
        if isinstance(value, cdist.core.property.FileList):
            self.__requirements = value
        else:
            self.__requirements = cdist.core.property.FileList(os.path.join(self.path, "require"), value)
    ### /requirements


    ### parameters
    @property
    def parameters(self):
        if not self.__parameters:
            self.__parameters = cdist.core.property.DirectoryDict(os.path.join(self.path, "parameter"))
        return self.__parameters

    @parameters.setter
    def parameters(self, value):
        if isinstance(value, cdist.core.property.DirectoryDict):
            self.__parameters = value
        else:
            self.__parameters = cdist.core.property.DirectoryDict(os.path.join(self.path, "parameter"), value)
    ### /parameters


    ### changed
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
    ### /changed

    # FIXME: implement other properties/methods 

    # FIXME: check following methods: implement or revoke / delete
    # FIXME: Object
    def get_object_id_from_object(self, cdist_object):
        """Returns everything but the first part (i.e. object_id) of an object"""
        return os.sep.join(cdist_object.split(os.sep)[1:])

    # FIXME: Object
    def object_dir(self, cdist_object):
        """Returns the full path to the object (including .cdist)"""
        return os.path.join(self.object_base_dir, cdist_object, DOT_CDIST)

    # FIXME: Object
    def remote_object_dir(self, cdist_object):
        """Returns the remote full path to the object (including .cdist)"""
        return os.path.join(REMOTE_OBJECT_DIR, cdist_object, DOT_CDIST)

    # FIXME: Object
    def object_parameter_dir(self, cdist_object):
        """Returns the dir to the object parameter"""
        return os.path.join(self.object_dir(cdist_object), "parameter")

    # FIXME: object
    def remote_object_parameter_dir(self, cdist_object):
        """Returns the remote dir to the object parameter"""
        return os.path.join(self.remote_object_dir(cdist_object), "parameter")

    # FIXME: object
    def object_code_paths(self, cdist_object):
        """Return paths to code scripts of object"""
        return [os.path.join(self.object_dir(cdist_object), "code-local"),
                  os.path.join(self.object_dir(cdist_object), "code-remote")]

    # Stays here
    def list_object_paths(self, starting_point):
        """Return list of paths of existing objects"""
        object_paths = []
        
        for content in os.listdir(starting_point):
            full_path = os.path.join(starting_point, content)
            if os.path.isdir(full_path):
                object_paths.extend(self.list_object_paths(starting_point = full_path))
                
            # Directory contains .cdist -> is an object
            if content == DOT_CDIST:
                object_paths.append(starting_point)
                
        return object_paths

    # Stays here
    def list_objects(self):
        """Return list of existing objects"""
        
        objects = []
        if os.path.isdir(self.object_base_dir):
            object_paths = self.list_object_paths(self.object_base_dir)
            
            for path in object_paths:
                objects.append(os.path.relpath(path, self.object_base_dir))
                
        return objects

    # FIXME: object
    def type_explorer_output_dir(self, cdist_object):
        """Returns and creates dir of the output for a type explorer"""
        dir = os.path.join(self.object_dir(cdist_object), "explorer")
        if not os.path.isdir(dir):
            os.mkdir(dir)

        return dir

