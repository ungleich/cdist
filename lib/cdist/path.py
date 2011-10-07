# -*- coding: utf-8 -*-
#
# 2010-2011 Nico Schottelius (nico-cdist at schottelius.org)
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
import shutil
import sys
import tempfile

# Hardcoded paths usually not changable
REMOTE_BASE_DIR                 = "/var/lib/cdist"
REMOTE_CONF_DIR                 = os.path.join(REMOTE_BASE_DIR, "conf")
REMOTE_OBJECT_DIR               = os.path.join(REMOTE_BASE_DIR, "object")
REMOTE_TYPE_DIR                 = os.path.join(REMOTE_CONF_DIR, "type")
REMOTE_GLOBAL_EXPLORER_DIR      = os.path.join(REMOTE_CONF_DIR, "explorer")

DOT_CDIST                       = ".cdist"

log = logging.getLogger(__name__)

import cdist.exec

def file_to_list(filename):
    """Return list from \n seperated file"""
    if os.path.isfile(filename):
        file_fd = open(filename, "r")
        lines = file_fd.readlines()
        file_fd.close()

        # Remove \n from all lines
        lines = map(lambda s: s.strip(), lines)
    else:
        lines = []

    return lines

class Path:
    """Class that handles path related configurations"""

    def __init__(self,
                target_host,
                initial_manifest=False,
                base_dir=None,
                debug=False):

        # Base and Temp Base 
        if base_dir:
            self.base_dir = base_dir
        else:
            self.base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir, os.pardir))

        self.temp_dir = tempfile.mkdtemp()

        self.target_host = target_host

        # Input directories
        self.conf_dir               = os.path.join(self.base_dir, "conf")
        self.cache_base_dir         = os.path.join(self.base_dir, "cache")
        self.cache_dir              = os.path.join(self.cache_base_dir, target_host)
        self.global_explorer_dir    = os.path.join(self.conf_dir, "explorer")
        self.lib_dir                = os.path.join(self.base_dir, "lib")
        self.manifest_dir           = os.path.join(self.conf_dir, "manifest")
        self.type_base_dir          = os.path.join(self.conf_dir, "type")

        # Mostly static, but can be overwritten on user demand
        if initial_manifest:
            self.initial_manifest = initial_manifest
        else:
            self.initial_manifest = os.path.join(self.manifest_dir, "init")

        # Output directories
        self.out_dir = os.path.join(self.temp_dir, "out")
        self.global_explorer_out_dir = os.path.join(self.out_dir, "explorer")
        self.object_base_dir = os.path.join(self.out_dir, "object")
        self.bin_dir = os.path.join(self.out_dir, "bin")

        os.environ['__cdist_out_dir'] = self.out_dir

        # List of type explorers transferred
        self.type_explorers_transferred = {}

        # objects prepared
        self.objects_prepared = []

        # Create directories
        self.__init_out_dirs()

    def cleanup(self):
        # Do not use in __del__:
        # http://docs.python.org/reference/datamodel.html#customization
        # "other globals referenced by the __del__() method may already have been deleted 
        # or in the process of being torn down (e.g. the import machinery shutting down)"
        #
        log.debug("Saving" + self.temp_dir + "to " + self.cache_dir)
        # Remove previous cache
        if os.path.exists(self.cache_dir):
            shutil.rmtree(self.cache_dir)
        shutil.move(self.temp_dir, self.cache_dir)


    def __init_out_dirs(self):
        """Initialise output directory structure"""
        os.mkdir(self.out_dir)
        os.mkdir(self.global_explorer_out_dir)
        os.mkdir(self.bin_dir)


    # Stays here
    def list_types(self):
        """Retuns list of types"""
        return os.listdir(self.type_base_dir)

    ###################################################################### 

    # FIXME: belongs to here - clearify remote*
    def remote_mkdir(self, directory):
        """Create directory on remote side"""
        cdist.exec.run_or_fail(["mkdir", "-p", directory], remote_prefix=True)

    # FIXME: belongs to here - clearify remote*
    def remove_remote_dir(self, destination):
        cdist.exec.run_or_fail(["rm", "-rf",  destination], remote_prefix=True)

    # FIXME: belongs to here - clearify remote*
    def transfer_dir(self, source, destination):
        """Transfer directory and previously delete the remote destination"""
        self.remove_remote_dir(destination)
        cdist.exec.run_or_fail(os.environ['__remote_copy'].split() +
            ["-r", source, self.target_host + ":" + destination])

    # FIXME: belongs to here - clearify remote*
    def transfer_file(self, source, destination):
        """Transfer file"""
        cdist.exec.run_or_fail(os.environ['__remote_copy'].split() +
            [source, self.target_host + ":" + destination])

    # FIXME: Explorer or stays
    def global_explorer_output_path(self, explorer):
        """Returns path of the output for a global explorer"""
        return os.path.join(self.global_explorer_out_dir, explorer)

    # FIXME: object
    def type_explorer_output_dir(self, cdist_object):
        """Returns and creates dir of the output for a type explorer"""
        dir = os.path.join(self.object_dir(cdist_object), "explorer")
        if not os.path.isdir(dir):
            os.mkdir(dir)

        return dir

    # FIXME Stays here / Explorer?
    def remote_global_explorer_path(self, explorer):
        """Returns path to the remote explorer"""
        return os.path.join(REMOTE_GLOBAL_EXPLORER_DIR, explorer)

    # FIXME: stays here
    def list_global_explorers(self):
        """Return list of available explorers"""
        return os.listdir(self.global_explorer_dir)

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
    def list_objects(self):
        """Return list of existing objects"""

        objects = []
        if os.path.isdir(self.object_base_dir):
            object_paths = self.list_object_paths(self.object_base_dir)

            for path in object_paths:
                objects.append(os.path.relpath(path, self.object_base_dir))

        return objects

    # Stays here
    def transfer_object_parameter(self, cdist_object):
        """Transfer the object parameter to the remote destination"""
        # Create base path before using mkdir -p
        self.remote_mkdir(self.remote_object_parameter_dir(cdist_object))

        # Synchronise parameter dir afterwards
        self.transfer_dir(self.object_parameter_dir(cdist_object), 
                                self.remote_object_parameter_dir(cdist_object))

    # Stays here
    def transfer_global_explorers(self):
        """Transfer the global explorers"""
        self.remote_mkdir(REMOTE_GLOBAL_EXPLORER_DIR)
        self.transfer_dir(self.global_explorer_dir, REMOTE_GLOBAL_EXPLORER_DIR)

    # Stays here - FIXME: adjust to type code, loop over types!
    def transfer_type_explorers(self, type):
        """Transfer explorers of a type, but only once"""
        if type.transferred_explorers:
            log.debug("Skipping retransfer for explorers of %s", type)
            return
        else:
            # Do not retransfer
            type.transferred_explorers = True

        # FIXME: Can be explorer_path or explorer_dir, I don't care.
        src = type.explorer_path()
        dst = type.remote_explorer_path()

        # Transfer if there is at least one explorer
        if len(type.explorers) > 0:
            # Ensure that the path exists
            self.remote_mkdir(dst)
            self.transfer_dir(src, dst)
