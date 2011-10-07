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


log = logging.getLogger(__name__)

import cdist.exec

class Context:
    """Storing context dependent information"""

    def __init__(self, target_host, initial_manifest=False, base_dir=False,
        debug=False):

        self.target_host = target_host

        # Base and Temp Base 
        if base_dir:
            self.base_dir = base_dir
        elif "__cdist_base_dir" in os.environ:
            self.base_dir = os.environ['__cdist_base_dir']
        else:
            self.base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir, os.pardir))

        # Input directories
        self.cache_dir              = os.path.join(self.base_dir, "cache", target_host)
        self.conf_dir               = os.path.join(self.base_dir, "conf")
        self.manifest_dir           = os.path.join(self.conf_dir, "manifest")

        # Probably unused paths
        # self.global_explorer_dir    = os.path.join(self.conf_dir, "explorer")
        # self.lib_dir                = os.path.join(self.base_dir, "lib")
        # self.type_base_dir          = os.path.join(self.conf_dir, "type")

        # Mostly static, but can be overwritten on user demand
        if initial_manifest:
            self.initial_manifest = initial_manifest
        else:
            self.initial_manifest = os.path.join(self.manifest_dir, "init")

        # Output directories
        if "__cdist_out_dir" in os.environ:
            self.out_dir = os.environ['__cdist_out_dir']
        else:
            self.out_dir = os.path.join(tempfile.mkdtemp(), "out")

        self.global_explorer_out_dir = os.path.join(self.out_dir, "explorer")
        self.object_base_dir = os.path.join(self.out_dir, "object")
        self.bin_dir = os.path.join(self.out_dir, "bin")

        # Remote directories
        if "__cdist_remote_base_dir" in os.environ:
            self.remote_base_dir = os.environ['__cdist_remote_base_dir']
        else:
            self.remote_base_dir = "/var/lib/cdist"

        self.remote_conf_dir            = os.path.join(self.remote_base_dir, "conf")
        self.remote_object_dir          = os.path.join(self.remote_base_dir, "object")
        self.remote_type_dir            = os.path.join(self.remote_conf_dir, "type")
        self.remote_global_explorer_dir = os.path.join(self.remote_conf_dir, "explorer")

        # Create directories
        self.__init_out_dirs()

    def cleanup(self):
        # Do not use in __del__:
        # http://docs.python.org/reference/datamodel.html#customization
        # "other globals referenced by the __del__() method may already have been deleted 
        # or in the process of being torn down (e.g. the import machinery shutting down)"
        #
        log.debug("Saving" + self.base_dir + "to " + self.cache_dir)
        # Remove previous cache
        if os.path.exists(self.cache_dir):
            shutil.rmtree(self.cache_dir)
        shutil.move(self.base_dir, self.cache_dir)

    def __init_env(self):
        """Setup environment"""
        os.environ['__cdist_out_dir'] = self.out_dir

    def __init_out_dirs(self):
        """Initialise output directory structure"""

        # Create base dir, if user supplied and not existing
        if not os.path.isdir(self.base_dir):
            os.mkdir(self.base_dir)
            
        os.mkdir(self.out_dir)
        os.mkdir(self.global_explorer_out_dir)
        os.mkdir(self.bin_dir)

    def remote_mkdir(self, directory):
        """Create directory on remote side"""
        cdist.exec.run_or_fail(["mkdir", "-p", directory], remote_prefix=True)

    def remove_remote_dir(self, destination):
        cdist.exec.run_or_fail(["rm", "-rf",  destination], remote_prefix=True)

