# -*- coding: utf-8 -*-
#
# 2020 Nico Schottelius (nico-cdist at schottelius.org)
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

log = logging.getLogger("scan")


# define this outside of the class to not handle scapy import errors by default
def commandline(args):
    log.debug(args)

    try:
        import cdist.scan.scan as scan
    except ModuleNotFoundError:
        print('cdist scan requires scapy to be installed')

    processes = []

    if not args.mode:
        # By default scan and trigger, but do not call any action
        args.mode = ['scan', 'trigger', ]

    if 'trigger' in args.mode:
        t = scan.Trigger(interfaces=args.interfaces)
        t.start()
        processes.append(t)
        log.debug("Trigger started")

    if 'scan' in args.mode:
        s = scan.Scanner(interfaces=args.interfaces, args=args)
        s.start()
        processes.append(s)
        log.debug("Scanner started")

    for process in processes:
        process.join()
