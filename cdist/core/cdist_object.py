# -*- coding: utf-8 -*-
#
# 2011-2017 Steven Armstrong (steven-cdist at armstrong.cc)
# 2011-2015 Nico Schottelius (nico-cdist at schottelius.org)
# 2014 Daniel Heule (hda at sfs.biz)
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
import cdist.core
from cdist.util import fsproperty


class IllegalObjectIdError(cdist.Error):
    def __init__(self, object_id, message=None):
        self.object_id = object_id
        self.message = message or 'Illegal object id'

    def __str__(self):
        return '%s: %s' % (self.message, self.object_id)


class MissingObjectIdError(cdist.Error):
    def __init__(self, type_name):
        self.type_name = type_name
        self.message = ("Type %s requires object id (is not a "
                        "singleton type)") % self.type_name

    def __str__(self):
        return '%s' % (self.message)


class CdistObject(object):
    """Represents a cdist object.

    All interaction with objects in cdist should be done through this class.
    Directly accessing an object through the file system from python code is
    a bug.

    """

    # Constants for use with Object.state
    STATE_UNDEF = ""
    STATE_PREPARED = "prepared"
    STATE_RUNNING = "running"
    STATE_DONE = "done"

    def __init__(self, cdist_type, base_path, object_marker, object_id):
        self.cdist_type = cdist_type  # instance of Type
        self.base_path = base_path
        self.object_id = object_id

        self.object_marker = object_marker

        self.validate_object_id()
        self.sanitise_object_id()

        self.name = self.join_name(self.cdist_type.name, self.object_id)
        self.path = os.path.join(self.cdist_type.path, self.object_id,
                                 self.object_marker)

        self.absolute_path = os.path.join(self.base_path, self.path)
        self.code_local_path = os.path.join(self.path, "code-local")
        self.code_remote_path = os.path.join(self.path, "code-remote")
        self.parameter_path = os.path.join(self.path, "parameter")
        self.stdout_path = os.path.join(self.absolute_path, "stdout")
        self.stderr_path = os.path.join(self.absolute_path, "stderr")

    @classmethod
    def list_objects(cls, object_base_path, type_base_path, object_marker):
        """Return a list of object instances"""
        for object_name in cls.list_object_names(
                object_base_path, object_marker):
            type_name, object_id = cls.split_name(object_name)
            yield cls(cdist.core.CdistType(type_base_path, type_name),
                      base_path=object_base_path,
                      object_marker=object_marker,
                      object_id=object_id)

    @classmethod
    def list_object_names(cls, object_base_path, object_marker):
        """Return a list of object names"""
        for path, dirs, files in os.walk(object_base_path):
            if object_marker in dirs:
                yield os.path.relpath(path, object_base_path)

    @classmethod
    def list_type_names(cls, object_base_path):
        """Return a list of type names"""
        return cdist.core.listdir(object_base_path)

    @staticmethod
    def split_name(object_name):
        """split_name('__type_name/the/object_id') -> ('__type_name', 'the/object_id')

        Split the given object name into it's type and object_id parts.

        """
        type_name = object_name.split(os.sep)[0]
        object_id = os.sep.join(object_name.split(os.sep)[1:])
        return type_name, object_id

    @staticmethod
    def join_name(type_name, object_id):
        """join_name('__type_name', 'the/object_id') -> __type_name/the/object_id'

        Join the given type_name and object_id into an object name.

        """
        return os.path.join(type_name, object_id)

    def validate_object_id(self):
        if self.cdist_type.is_singleton and self.object_id:
            raise IllegalObjectIdError(('singleton objects can\'t have an '
                                        'object_id'))

        """Validate the given object_id and raise IllegalObjectIdError
           if it's not valid.
        """
        if self.object_id:
            if self.object_marker in self.object_id.split(os.sep):
                raise IllegalObjectIdError(
                        self.object_id, ('object_id may not contain '
                                         '\'%s\'') % self.object_marker)
            if '//' in self.object_id:
                raise IllegalObjectIdError(
                        self.object_id, 'object_id may not contain //')

            _invalid_object_ids = ('.', '/', )
            for ioid in _invalid_object_ids:
                if self.object_id == ioid:
                    raise IllegalObjectIdError(
                        self.object_id,
                        'object_id may not be a {}'.format(ioid))

        # If no object_id and type is not singleton => error out
        if not self.object_id and not self.cdist_type.is_singleton:
            raise MissingObjectIdError(self.cdist_type.name)

        # Does not work:
        # AttributeError:
        # 'CdistObject' object has no attribute 'parameter_path'

        # "Type %s is not a singleton type - missing object id
        # (parameters: %s)" % (self.cdist_type.name, self.parameters))

    def object_from_name(self, object_name):
        """Convenience method for creating an object instance from an object name.

        Mainly intended to create objects when resolving requirements.

        e.g:
            <CdistObject __foo/bar>.object_from_name('__other/object') ->
                <CdistObject __other/object>

        """

        base_path = self.base_path
        type_path = self.cdist_type.base_path
        object_marker = self.object_marker

        type_name, object_id = self.split_name(object_name)

        cdist_type = self.cdist_type.__class__(type_path, type_name)

        return self.__class__(cdist_type, base_path, object_marker,
                              object_id=object_id)

    def __repr__(self):
        return '<CdistObject %s>' % self.name

    def __eq__(self, other):
        """define equality as 'name is the same'"""
        return self.name == other.name

    def __hash__(self):
        return hash(self.name)

    def __lt__(self, other):
        return isinstance(other, self.__class__) and self.name < other.name

    def sanitise_object_id(self):
        """
        Remove leading and trailing slash (one only)
        """

        # Allow empty object id for singletons
        if self.object_id:
            # Remove leading slash
            if self.object_id[0] == '/':
                self.object_id = self.object_id[1:]

            # Remove trailing slash
            if self.object_id[-1] == '/':
                self.object_id = self.object_id[:-1]

    # FIXME: still needed?
    @property
    def explorer_path(self):
        """Create and return the relative path to this objects explorers"""
        # create absolute path
        path = os.path.join(self.absolute_path, "explorer")
        if not os.path.isdir(path):
            os.mkdir(path)
        # return relative path
        return os.path.join(self.path, "explorer")

    requirements = fsproperty.FileListProperty(
            lambda obj: os.path.join(obj.absolute_path, 'require'))
    autorequire = fsproperty.FileListProperty(
            lambda obj: os.path.join(obj.absolute_path, 'autorequire'))
    parameters = fsproperty.DirectoryDictProperty(
            lambda obj: os.path.join(obj.base_path, obj.parameter_path))
    explorers = fsproperty.DirectoryDictProperty(
            lambda obj: os.path.join(obj.base_path, obj.explorer_path))
    state = fsproperty.FileStringProperty(
            lambda obj: os.path.join(obj.absolute_path, "state"))
    source = fsproperty.FileListProperty(
            lambda obj: os.path.join(obj.absolute_path, "source"))
    code_local = fsproperty.FileStringProperty(
            lambda obj: os.path.join(obj.base_path, obj.code_local_path))
    code_remote = fsproperty.FileStringProperty(
            lambda obj: os.path.join(obj.base_path, obj.code_remote_path))

    @property
    def exists(self):
        """Checks wether this cdist object exists on the file systems."""
        return os.path.exists(self.absolute_path)

    def create(self, allow_overwrite=False):
        """Create this cdist object on the filesystem.
        """
        try:
            for path in (self.absolute_path,
                         os.path.join(self.base_path, self.parameter_path),
                         self.stdout_path,
                         self.stderr_path):
                os.makedirs(path, exist_ok=allow_overwrite)
        except EnvironmentError as error:
            raise cdist.Error(('Error creating directories for cdist object: '
                               '%s: %s') % (self, error))

    def requirements_unfinished(self, requirements):
        """Return state whether requirements are satisfied"""

        object_list = []

        for requirement in requirements:
            cdist_object = self.object_from_name(requirement)

            if not cdist_object.state == self.STATE_DONE:
                object_list.append(cdist_object)

        return object_list
