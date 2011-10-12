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

import io
import logging
import os
#import stat
#import shutil
#import sys
#import tempfile
#import time
#
#import cdist.exec

import cdist

log = logging.getLogger(__name__)

class GlobalExplorer(object):
    """Execute explorers"""

    def __init__(self, local_path, remote_path):
        self.local_path     = local_path
        self.remote_path    = remote_path

    def run(self):
        """Run global explorers"""
        log.info("Running global explorers")

        outputs = {}
        for explorer in os.listdir(src_path):
            outputs[explorer] = io.StringIO()
            cmd = []
            cmd.append("__explorer=" + remote_dst_path)
            cmd.append(os.path.join(remote_dst_path, explorer))
            cdist.exec.run_or_fail(cmd, stdout=outputs[explorer], remote_prefix=True)

    def transfer(self):
        """Transfer the global explorers"""
        self.remote_mkdir(self.remote_global_explorer_path)
        self.transfer_path(self.global_explorer_path, 
            self.remote_global_explorer_path)
