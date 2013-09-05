# -*- coding: utf-8 -*-
#
# 2013-2015 Nico Schottelius (nico-cdist at schottelius.org)
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
import tempfile

# initialise cdist
import cdist.exec.local


import cdist.config

log = logging.getLogger(__name__)


class Shell(object):

    def __init__(self, shell=None):

        self.shell = shell

        self.target_host = (
            "cdist-shell-no-target-host",
            "cdist-shell-no-target-host",
            "cdist-shell-no-target-host",
        )
        self.target_host_tags = ""

        host_dir_name = cdist.str_hash(self.target_host[0])
        base_root_path = tempfile.mkdtemp()
        host_base_path = os.path.join(base_root_path, host_dir_name)

        self.local = cdist.exec.local.Local(
            target_host=self.target_host,
            target_host_tags=self.target_host_tags,
            base_root_path=host_base_path,
            host_dir_name=host_dir_name)

    def _init_shell(self):
        """Select shell to execute, if not specified by user"""

        if not self.shell:
            self.shell = os.environ.get('SHELL', "/bin/sh")

    def _init_files_dirs(self):
        self.local.create_files_dirs()

    def _init_environment(self):
        self.env = os.environ.copy()
        additional_env = {
            'PATH': "%s:%s" % (self.local.bin_path, os.environ['PATH']),
            # for use in type emulator
            '__cdist_type_base_path': self.local.type_path,
            '__cdist_manifest': "cdist shell",
            '__global': self.local.base_path,
            '__target_host': self.target_host[0],
            '__target_hostname': self.target_host[1],
            '__target_fqdn': self.target_host[2],
            '__manifest': self.local.manifest_path,
            '__explorer': self.local.global_explorer_path,
            '__files': self.local.files_path,
            '__target_host_tags': self.local.target_host_tags,
        }

        self.env.update(additional_env)

    def run(self):
        self._init_shell()
        self._init_files_dirs()
        self._init_environment()

        log.trace("Starting shell...")
        self.local.run([self.shell], self.env, save_output=False)
        log.trace("Finished shell.")

    @classmethod
    def commandline(cls, args):
        shell = cls(args.shell)
        shell.run()
