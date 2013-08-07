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

# FIXME: only considering config here - enable
# command line switch for using install object
# when it is available
import cdist.config

log = logging.getLogger(__name__)

class Shell(object):
    
    def __init__(self):
        pass

    @classmethod
    def commandline(cls, args):
        pass
        # initialise cdist
        import cdist.context

        context = cdist.context.Context(
            target_host="cdist-shell-no-target-host",
            remote_copy=cdist.REMOTE_COPY,
            remote_exec=cdist.REMOTE_EXEC)

        config = cdist.config.Config(context)

        # Startup Shell
        if args.shell:
            shell = [args.shell]
        elif 'SHELL' in os.environ:
            shell = [os.environ['SHELL']]
        else:
            shell = ["/bin/sh"]

        log.info("Starting shell...")
        subprocess.call(shell)
