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
    """Storing context information"""

    def __init__(self,
        target_host,
        initial_manifest=False,
        base_path=False,
        out_path=False,
        remote_base_path=False,
        debug=False):

        self.target_host = target_host

        # Base and Temp Base 
        if base_path:
            self.base_path = base_path
        else:
            self.base_path = os.path.abspath(
                os.path.join(os.path.dirname(__file__),
                    os.pardir,
                    os.pardir))
        

        # Local input directories
        self.cache_path              = os.path.join(self.base_path, "cache", target_host)
        self.conf_path               = os.path.join(self.base_path, "conf")

        self.global_explorer_path    = os.path.join(self.conf_path, "explorer")
        self.manifest_path           = os.path.join(self.conf_path, "manifest")
        self.type_base_path          = os.path.join(self.conf_path, "type")
        self.lib_path                = os.path.join(self.base_path, "lib")

        if initial_manifest:
            self.initial_manifest = initial_manifest
        else:
            self.initial_manifest = os.path.join(self.manifest_path, "init")

        # Local output directories
        if out_path:
            self.out_path = out_path
        else:
            self.out_path = os.path.join(tempfile.mkdtemp(), "out")

        self.bin_path                 = os.path.join(self.out_path, "bin")
        self.global_explorer_out_path = os.path.join(self.out_path, "explorer")
        self.object_base_path         = os.path.join(self.out_path, "object")

        # Remote directories
        if remote_base_path:
            self.remote_base_path = remote_base_path
        else:
            self.remote_base_path = "/var/lib/cdist"

        self.remote_conf_path            = os.path.join(self.remote_base_path, "conf")
        self.remote_object_path          = os.path.join(self.remote_base_path, "object")
        self.remote_type_path            = os.path.join(self.remote_conf_path, "type")
        self.remote_global_explorer_path = os.path.join(self.remote_conf_path, "explorer")

        # Create directories
        self.__init_out_paths()
        self.__init_remote_paths()

    def cleanup(self):
        # Do not use in __del__:
        # http://docs.python.org/reference/datamodel.html#customization
        # "other globals referenced by the __del__() method may already have been deleted 
        # or in the process of being torn down (e.g. the import machinery shutting down)"
        #
        log.debug("Saving" + self.base_path + "to " + self.cache_path)
        # Remove previous cache
        if os.path.exists(self.cache_path):
            shutil.rmtree(self.cache_path)
        shutil.move(self.base_path, self.cache_path)

    def __init_out_paths(self):
        """Initialise output directory structure"""

        # Create base dir, if user supplied and not existing
        if not os.path.isdir(self.base_path):
            os.mkdir(self.base_path)
            
        os.mkdir(self.out_path)
        os.mkdir(self.global_explorer_out_path)
        os.mkdir(self.bin_path)

    def __init_remote_paths(self):
        """Initialise remote directory structure"""

        self.remove_remote_path(self.remote_base_path)
        self.remote_mkdir(self.remote_base_path)

    def remote_mkdir(self, directory):
        """Create directory on remote side"""
        cdist.exec.run_or_fail(["mkdir", "-p", directory], remote_prefix=True)

    def remove_remote_path(self, destination):
        cdist.exec.run_or_fail(["rm", "-rf",  destination], remote_prefix=True)

    def transfer_path(self, source, destination):
        """Transfer directory and previously delete the remote destination"""
        self.remove_remote_path(destination)
        cdist.exec.run_or_fail(os.environ['__remote_copy'].split() +
            ["-r", source, self.target_host + ":" + destination])
