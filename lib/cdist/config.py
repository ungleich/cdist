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

import datetime
import logging
log = logging.getLogger(__name__)

<<<<<<< HEAD
import cdist.config_install
>>>>>>> master

class Config(cdist.config_install.ConfigInstall):
    pass

def config(args):
    """Configure remote system"""
    process = {}

    time_start = datetime.datetime.now()

    os.environ['__remote_exec'] = "ssh -o User=root -q"
    os.environ['__remote_copy'] = "scp -o User=root -q"

    for host in args.host:
        c = Config(host, initial_manifest=args.manifest, home=args.cdist_home, debug=args.debug)
        if args.parallel:
            log.debug("Creating child process for %s", host)
            process[host] = multiprocessing.Process(target=c.deploy_and_cleanup)
            process[host].start()
        else:
            c.deploy_and_cleanup()

    if args.parallel:
        for p in process.keys():
            log.debug("Joining process %s", p)
            process[p].join()

    time_end = datetime.datetime.now()
    log.info("Total processing time for %s host(s): %s", len(args.host),
                (time_end - time_start).total_seconds())
