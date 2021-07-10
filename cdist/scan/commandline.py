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
        t = scan.Trigger(interfaces=args.interface,
                         sleeptime=args.trigger_delay)
        t.start()
        processes.append(t)
        log.debug("Trigger started")

    if 'scan' in args.mode:
        s = scan.Scanner(
                autoconfigure='config' in args.mode,
                interfaces=args.interface,
                name_mapper=args.name_mapper)
        s.start()
        processes.append(s)
        log.debug("Scanner started")

    for process in processes:
        process.join()


def list(scan, args):
    s = scan.Scanner(interfaces=args.interface, name_mapper=args.name_mapper)
    hosts = s.list()

    # A full IPv6 addresses id composed of 8 blocks of 4 hexa chars +
    # 6 colons.
    ipv6_max_size = 8 * 4 + 10
    date_max_size = len(datetime.now().strftime(scan.datetime_format))
    name_max_size = 25

    print("{} | {} | {} | {}".format(
        'name'.ljust(name_max_size),
        'address'.ljust(ipv6_max_size),
        'last seen'.ljust(date_max_size),
        'last configured'.ljust(date_max_size)))
    print('=' * (name_max_size + 3 + ipv6_max_size + 2 * (3 + date_max_size)))
    for host in hosts:
        last_seen = host.last_seen()
        if last_seen:
            last_seen = last_seen.strftime(scan.datetime_format)
        else:
            last_seen = '-'

        last_configured = host.last_configured()
        if last_configured is not None:
            last_configured = last_configured.strftime(scan.datetime_format)
        else:
            last_configured = '-'

        print("{} | {} | {} | {}".format(
            host.name(default='-').ljust(name_max_size),
            host.address().ljust(ipv6_max_size),
            last_seen.ljust(date_max_size),
            last_configured.ljust(date_max_size)))


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

    if 'config' in args.mode and args.name_mapper is None:
        print('--name-mapper must be specified for scanner config mode.',
              file=sys.stderr)
        sys.exit(1)

    # Print known hosts and exit is --list is specified - do not start
    # the scanner.
    if args.list:
        list(scan, args)
    else:
        run(scan, args)
