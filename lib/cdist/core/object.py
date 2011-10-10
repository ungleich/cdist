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

# FIXME: i should not have to care about prefix directory, local, remote and such.
#  I know what my internals look like, the outside is none of my business.
class Object(object):
    """Represents a cdist object.

    All interaction with objects in cdist should be done through this class.
    Directly accessing an object through the file system from python code is 
    a bug.

    """

    @classmethod
    def list_objects(cls, object_base_path, type_base_path):
        """Return a list of object instances"""
        for object_name in cls.list_object_names(object_base_path):
            type_name = object_name.split(os.sep)[0]
            # FIXME: allow object without object_id? e.g. for singleton
            object_id = os.sep.join(object_name.split(os.sep)[1:])
            yield cls(cdist.core.Type(type_base_path, type_name), object_base_path, object_id=object_id)

    @classmethod
    def list_type_names(cls, object_base_path):
        """Return a list of type names"""
        return os.listdir(object_base_path)

    @classmethod
    def list_object_names(cls, object_base_path):
        """Return a list of object names"""
        for path, dirs, files in os.walk(object_base_path):
            if DOT_CDIST in dirs:
                yield os.path.relpath(path, object_base_path)

    def __init__(self, type, base_path, object_id=None):
        self.type = type # instance of Type
        self.base_path = base_path
        self.object_id = object_id
        self.name = os.path.join(self.type.name, self.object_id)
        self.path = os.path.join(self.type.path, self.object_id, DOT_CDIST)
        self.absolute_path = os.path.join(self.base_path, self.path)
        self.code_local_path = os.path.join(self.path, "code-local")
        self.code_remote_path = os.path.join(self.path, "code-remote")
        self.parameter_path = os.path.join(self.path, "parameter")

        self.__parameters = None
        self.__requirements = None

    def __repr__(self):
        return '<Object %s>' % self.name

    def __eq__(self, other):
        """define equality as 'attributes are the same'"""
        return self.__dict__ == other.__dict__

    @property
    def explorer_path(self):
        # create absolute path
        path = os.path.join(self.absolute_path, "explorer")
        if not os.path.isdir(path):
            os.mkdir(path)
        # return relative path
        return os.path.join(self.path, "explorer")


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
            self.__parameters = cdist.core.property.DirectoryDict(os.path.join(self.absolute_path, "parameter"))
        return self.__parameters

    @parameters.setter
    def parameters(self, value):
        if isinstance(value, cdist.core.property.DirectoryDict):
            self.__parameters = value
        else:
            self.__parameters = cdist.core.property.DirectoryDict(os.path.join(self.absolute_path, "parameter"), value)
    ### /parameters


    ### changed
    @property
    def changed(self):
        """Check whether the object has been changed."""
        return os.path.isfile(os.path.join(self.absolute_path, "changed"))

    @changed.setter
    def changed(self, value):
        """Change the objects changed status."""
        path = os.path.join(self.absolute_path, "changed")
        if value:
            open(path, "w").close()
        else:
            try:
                os.remove(path)
            except EnvironmentError:
                # ignore
                pass
    ### /changed


    ### prepared
    @property
    def prepared(self):
        """Check whether the object has been prepared."""
        return os.path.isfile(os.path.join(self.absolute_path, "prepared"))

    @prepared.setter
    def prepared(self, value):
        """Change the objects prepared status."""
        path = os.path.join(self.absolute_path, "prepared")
        if value:
            open(path, "w").close()
        else:
            try:
                os.remove(path)
            except EnvironmentError:
                # ignore
                pass
    ### /prepared


    ### ran
    @property
    def ran(self):
        """Check whether the object has been ran."""
        return os.path.isfile(os.path.join(self.absolute_path, "ran"))

    @ran.setter
    def ran(self, value):
        """Change the objects ran status."""
        path = os.path.join(self.absolute_path, "ran")
        if value:
            open(path, "w").close()
        else:
            try:
                os.remove(path)
            except EnvironmentError:
                # ignore
                pass
    ### /ran
