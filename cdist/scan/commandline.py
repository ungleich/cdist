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
import sys

log = logging.getLogger("scan")

# CLI processing is defined outside of the main scan class to handle
# non-available optional scapy dependency (instead of crashing mid-flight).
def commandline(args):
    log.debug(args)

    # Check if we have the optional scapy dependency available.
    try:
        import cdist.scan.scan as scan
    except ModuleNotFoundError:
        log.error('cdist scan requires scapy to be installed. Exiting.')
        sys.exit(1)

    # Default operation mode.
    if not args.mode:
        # By default scan and trigger, but do not call any action.
        args.mode = ['scan', 'trigger', ]

    # We run each component in a separate process since they
    # must not block on each other.
    processes = []

    if 'trigger' in args.mode:
        t = scan.Trigger(interfaces=args.interfaces, sleeptime=args.trigger_delay)
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
