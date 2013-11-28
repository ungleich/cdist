# -*- coding: utf-8 -*-
#
# 2013 Nico Schottelius (nico-cdist at schottelius.org)
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
import subprocess

# initialise cdist
import cdist.exec.local

import cdist.config

log = logging.getLogger(__name__)

class PreOS(object):
    
    def __init__(self, target_dir, arch="amd64"):

        self.target_dir = target_dir
        self.arch = arch

        self.command = "debootstrap"
        self.suite  = "wheezy"
        self.options = [ "--include=openssh-server",
            "--arch=%s" % self.arch ]

    def run(self):
        cmd = [ self.command ]
        cmd.extend(self.options)
        cmd.append(self.suite)
        cmd.append(self.target_dir)

        log.debug("Bootstrap: %s" % cmd)

        subprocess.call(cmd)


    @classmethod
    def commandline(cls, args):
        print(args)
        self = cls(target_dir=args.target_dir[0],
            arch=args.arch)
        self.run()
