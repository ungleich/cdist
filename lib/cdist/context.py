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
import shutil

from cdist.exec import local
from cdist.exec import remote


class Context(object):
    """Hold information about current context"""

    def __init__(self,
        target_host,
        remote_copy,
        remote_exec,
        initial_manifest=False,
        base_path=False,
        exec_path=sys.argv[0],
        debug=False):

        self.debug      = debug

        self.target_host    = target_host

        # Only required for testing
        self.exec_path      = exec_path

        # Context logging
        self.log = logging.getLogger(self.target_host)
        self.log.addFilter(self)

        # Local base directory
        self.base_path = (base_path or
            os.path.abspath(os.path.join(os.path.dirname(__file__),
                os.pardir, os.pardir)))

        # Local temp directory
        # FIXME: if __cdist_out_dir can be given from the outside, the same directory will be used for all hosts
        if '__cdist_out_dir' in os.environ:
            self.out_path = os.environ['__cdist_out_dir']
            self.temp_dir = None
        else:
            self.temp_dir = tempfile.mkdtemp()
            self.out_path = os.path.join(self.temp_dir, "out")

        self.local = local.Local(self.target_host, self.base_path, self.out_path)

        self.initial_manifest = (initial_manifest or
            os.path.join(self.local.manifest_path, "init"))

        self._init_remote(remote_copy, remote_exec)

    # Remote stuff
    def _init_remote(self, remote_copy, remote_exec):

        self.remote_base_path = os.environ.get('__cdist_remote_out_dir', "/var/lib/cdist")
        self.remote_copy = remote_copy
        self.remote_exec = remote_exec

        os.environ['__remote_copy'] = self.remote_copy
        os.environ['__remote_exec'] = self.remote_exec

        self.remote = remote.Remote(self.target_host, self.remote_base_path,
            self.remote_exec, self.remote_copy)

    def cleanup(self):
        """Remove temp stuff"""
        if self.temp_dir:
            shutil.rmtree(self.temp_dir)

    def filter(self, record):
        """Add hostname to logs via logging Filter"""

        record.msg = self.target_host + ": " + record.msg

        return True
