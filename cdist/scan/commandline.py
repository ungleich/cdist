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
from datetime import datetime

log = logging.getLogger("scan")

def run(scan, args):
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

def list(scan, args):
    s = scan.Scanner(interfaces=args.interfaces, args=args)
    hosts = s.list()

    # A full IPv6 addresses id composed of 8 blocks of 4 hexa chars +
    # 6 colons.
    ipv6_max_size = 8 * 4 + 10
    # We format dates as follow: YYYY-MM-DD HH:MM:SS
    date_max_size =              8 + 2    + 6 + 2

    print("{} | {}".format(
        'link-local address'.ljust(ipv6_max_size),
        'last seen'.ljust(date_max_size)))
    print('=' * (ipv6_max_size + 3 + date_max_size))
    for addr in hosts:
        last_seen = datetime.strftime(
                datetime.strptime(hosts[addr]['last_seen'].strip(), '%Y-%m-%d %H:%M:%S.%f'),
                '%Y-%m-%d %H:%M:%S')
        print("{} | {}".format(addr.ljust(ipv6_max_size),last_seen.ljust(date_max_size)))

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

    # Set default operation mode.
    if not args.mode:
        # By default scan and trigger, but do not call any action.
        args.mode = ['scan', 'trigger', ]

    # Print known hosts and exit is --list is specified - do not start
    # the scanner.
    if args.list:
        list(scan, args)
    else:
        run(scan, args)
