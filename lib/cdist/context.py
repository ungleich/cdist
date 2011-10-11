#!/usr/bin/env python3
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
import sys
import tempfile
#import stat
#import shutil
#import time
#
#import cdist.core
#import cdist.exec

class Context(object):
    """Hold information about current context"""

    def __init__(self,
        target_host,
        initial_manifest=False,
        base_path=False,
        exec_path=sys.argv[0],
        debug=False):

        self.target_host    = target_host

        # Only required for testing
        self.exec_path      = exec_path

        # Context logging
        self.log = logging.getLogger(self.target_host)
        self.log.addFilter(self)

        # Base and Temp Base 
        self.base_path = (base_path or
            os.path.abspath(os.path.join(os.path.dirname(__file__),
                os.pardir, os.pardir)))

        # Local input
        self.cache_path             = os.path.join(self.base_path, "cache", 
            self.target_host)
        self.conf_path              = os.path.join(self.base_path, "conf")

        self.global_explorer_path   = os.path.join(self.conf_path, "explorer")
        self.manifest_path          = os.path.join(self.conf_path, "manifest")
        self.type_base_path         = os.path.join(self.conf_path, "type")
        self.lib_path               = os.path.join(self.base_path, "lib")

        self.initial_manifest = (initial_manifest or
            os.path.join(self.manifest_path, "init"))

        # Local output
        if '__cdist_out_dir' in os.environ:
            self.out_path = os.environ['__cdist_out_dir']
            self.temp_dir = None
        else:
            self.temp_dir = tempfile.mkdtemp()
            self.out_path = os.path.join(self.temp_dir, "out")

        self.bin_path                 = os.path.join(self.out_path, "bin")
        self.global_explorer_out_path = os.path.join(self.out_path, "explorer")
        self.object_base_path         = os.path.join(self.out_path, "object")

        # Remote directory base
        if '__cdist_remote_out_dir' in os.environ:
            self.remote_base_path = os.environ['__cdist_remote_out_dir']
        else:
            self.remote_base_path = "/var/lib/cdist"

        self.remote_conf_path            = os.path.join(self.remote_base_path, "conf")
        self.remote_object_path          = os.path.join(self.remote_base_path, "object")

        self.remote_type_path            = os.path.join(self.remote_conf_path, "type")
        self.remote_global_explorer_path = os.path.join(self.remote_conf_path, "explorer")

        if '__remote_exec' in os.environ:
            self.remote_exec = os.environ['__remote_exec']
        else:
            self.remote_exec = "ssh -o User=root -q"

        if '__remote_copy' in os.environ:
            self.remote_copy = os.environ['__remote_copy']
        else:
            self.remote_copy = "scp -o User=root -q"

    def cleanup(self):
        """Remove temp stuff"""
        if self.temp_dir:
            shutil.rmtree(self.temp_dir)

    def filter(self, record):
        """Add hostname to logs via logging Filter"""

        record.msg = self.target_host + ": " + record.msg

        return True
