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
#import os
#import stat
#import shutil
#import sys
#import tempfile
#import time
#
#import cdist.core
#import cdist.exec

log = logging.getLogger(__name__)

class Explorer:
    """Execute explorers"""

    def __init__(self, context):
        self.context = context

    def run_type_explorer(self, cdist_object):
        """Run type specific explorers for objects"""

        cdist_type = cdist_object.type
        self.transfer_type_explorers(cdist_type)

        cmd = []
        cmd.append("__explorer="        + self.remote_global_explorer_path)
        cmd.append("__type_explorer="   + os.path.join(
                                            self.remote_type_path,
                                            cdist_type.explorer_path))
        cmd.append("__object="          + os.path.join(
                                            self.remote_object_path,
                                            cdist_object.path))
        cmd.append("__object_id="       + cdist_object.object_id)
        cmd.append("__object_fq="       + cdist_object.name)

        # Need to transfer at least the parameters for objects to be useful
        self.transfer_object_parameter(cdist_object)

        outputs = {}
        for explorer in cdist_type.explorers:
            remote_cmd = cmd + [os.path.join(self.remote_type_path,
                cdist_type.explorer_path, explorer)]
            outputs[explorer] = io.StringIO()
            log.debug("%s exploring %s using %s storing to %s", 
                            cdist_object, explorer, remote_cmd, output)
                        
            cdist.exec.run_or_fail(remote_cmd, stdout=outputs[explorer], remote_prefix=True)

        return outputs

    def run_global_explorers(self):
        """Run global explorers"""
        log.info("Running global explorers")

        src_path = self.global_explorer_path
        dst_path = self.remote_global_explorer_path

        self.transfer_path(src_path, dst_path)

        outputs = {}
        for explorer in os.listdir(src_path):
            outputs[explorer] = io.StringIO()
            cmd = []
            cmd.append("__explorer=" + remote_dst_path)
            cmd.append(os.path.join(remote_dst_path, explorer))
            cdist.exec.run_or_fail(cmd, stdout=outputs[explorer], remote_prefix=True)

    def transfer_object_parameter(self, cdist_object):
        """Transfer the object parameter to the remote destination"""
        src  = os.path.join(self.object_base_path,
            cdist_object.parameter_path)
        dst = os.path.join(self.remote_object_path,
            cdist_object.parameter_path)

        # Synchronise parameter dir afterwards
        self.remote_mkdir(dst)
        self.transfer_path(src, dst)

    def transfer_global_explorers(self):
        """Transfer the global explorers"""
        self.remote_mkdir(self.remote_global_explorer_path)
        self.transfer_path(self.global_explorer_path, 
            self.remote_global_explorer_path)

    def transfer_type_explorers(self, cdist_type):
        """Transfer explorers of a type, but only once"""
        if cdist_type.transferred_explorers:
            log.debug("Skipping retransfer for explorers of %s", cdist_type)
            return
        else:
            log.debug("Ensure no retransfer for %s", cdist_type)
            # Do not retransfer
            cdist_type.transferred_explorers = True

        explorers = cdist_type.explorers

        if len(explorers) > 0:
            rel_path = cdist_type.explorer_path
            src = os.path.join(self.type_base_path, rel_path)
            dst = os.path.join(self.remote_type_path, rel_path)

            # Ensure full path until type exists:
            # /var/lib/cdist/conf/type/__directory/explorer
            # /var/lib/cdist/conf/type/__directory may not exist,
            # but remote_mkdir uses -p to fix this
            self.remote_mkdir(dst)
            self.transfer_path(src, dst)

    def remote_mkdir(self, directory):
        """Create directory on remote side"""
        cdist.exec.run_or_fail(["mkdir", "-p", directory], remote_prefix=True)

    def remove_remote_path(self, destination):
        """Ensure path on remote side vanished"""
        cdist.exec.run_or_fail(["rm", "-rf",  destination], remote_prefix=True)

    def transfer_path(self, source, destination):
        """Transfer directory and previously delete the remote destination"""
        self.remove_remote_path(destination)
        cdist.exec.run_or_fail(os.environ['__remote_copy'].split() +
            ["-r", source, self.target_host + ":" + destination])
