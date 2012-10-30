#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2010-2012 Nico Schottelius (nico-cdist at schottelius.org)
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

def commandline():
    """Parse command line"""
    import argparse

    import cdist.banner
    import cdist.config
    import cdist.install

    # Construct parser others can reuse
    parser = {}
    # Options _all_ parsers have in common
    parser['loglevel'] = argparse.ArgumentParser(add_help=False)
    parser['loglevel'].add_argument('-d', '--debug',
        help='Set log level to debug', action='store_true',
        default=False)
    parser['loglevel'].add_argument('-v', '--verbose',
        help='Set log level to info, be more verbose',
        action='store_true', default=False)

    # Main subcommand parser
    parser['main'] = argparse.ArgumentParser(description='cdist ' + cdist.VERSION,
        parents=[parser['loglevel']])
    parser['main'].add_argument('-V', '--version',
        help='Show version', action='version',
        version='%(prog)s ' + cdist.VERSION)
    parser['sub'] = parser['main'].add_subparsers(title="Commands")

    # Banner
    parser['banner'] = parser['sub'].add_parser('banner', 
        parents=[parser['loglevel']])
    parser['banner'].set_defaults(func=cdist.banner.banner)

    # Config and install (common stuff)
    parser['configinstall'] = argparse.ArgumentParser(add_help=False)
    parser['configinstall'].add_argument('host', nargs='+',
        help='one or more hosts to operate on')
    parser['configinstall'].add_argument('-c', '--cdist-home',
         help='Change cdist home (default: .. from bin directory)',
         action='store')
    parser['configinstall'].add_argument('-i', '--initial-manifest', 
         help='Path to a cdist manifest or \'-\' to read from stdin.',
         dest='manifest', required=False)
    parser['configinstall'].add_argument('-p', '--parallel',
         help='Operate on multiple hosts in parallel',
         action='store_true', dest='parallel')
    parser['configinstall'].add_argument('-s', '--sequential',
         help='Operate on multiple hosts sequentially (default)',
         action='store_false', dest='parallel')

    parser['configinstall'].add_argument('--remote-copy',
         help='Command to use for remote copy (should behave like scp)',
         action='store', dest='remote_copy',
         default="scp -o User=root -q")
    parser['configinstall'].add_argument('--remote-exec',
         help='Command to use for remote execution (should behave like ssh)',
         action='store', dest='remote_exec',
         default="ssh -o User=root -q")

    # Config
    parser['config'] = parser['sub'].add_parser('config',
        parents=[parser['loglevel'], parser['configinstall']])
    parser['config'].set_defaults(func=config)

    # Install
    # 20120525/sar: commented until it actually does something
    #parser['install'] = parser['sub'].add_parser('install',
    #    parents=[parser['loglevel'], parser['configinstall']])
    #parser['install'].set_defaults(func=install)

    for p in parser:
        parser[p].epilog = "Get cdist at http://www.nico.schottelius.org/software/cdist/"

    args = parser['main'].parse_args(sys.argv[1:])

    # Loglevels are handled globally in here and debug wins over verbose
    if args.verbose:
        logging.root.setLevel(logging.INFO)
    if args.debug:
        logging.root.setLevel(logging.DEBUG)

    log.debug(args)
    args.func(args)

def config(args):
    configinstall(args, mode=cdist.config.Config)

def install(args):
    configinstall(args, mode=cdist.install.Install)

def configinstall(args, mode):
    """Configure or install remote system"""
    import multiprocessing
    import time

    initial_manifest_tempfile = None
    if args.manifest == '-':
        # read initial manifest from stdin
        import tempfile
        try:
            handle, initial_manifest_temp_path = tempfile.mkstemp(prefix='cdist.stdin.')
            with os.fdopen(handle, 'w') as fd:
                fd.write(sys.stdin.read())
        except (IOError, OSError) as e:
            raise cdist.Error("Creating tempfile for stdin data failed: %s" % e)

        args.manifest = initial_manifest_temp_path
        import atexit
        atexit.register(lambda: os.remove(initial_manifest_temp_path))

    process = {}
    failed_hosts = []
    time_start = time.time()

    for host in args.host:
        if args.parallel:
            log.debug("Creating child process for %s", host)
            process[host] = multiprocessing.Process(target=configinstall_onehost, args=(host, args, mode, True))
            process[host].start()
        else:
            try:
                configinstall_onehost(host, args, mode, parallel=False)
            except cdist.Error as e:
                failed_hosts.append(host)

    # Catch errors in parallel mode when joining
    if args.parallel:
        for host in process.keys():
            log.debug("Joining process %s", host)
            process[host].join()

            if not process[host].exitcode == 0:
                failed_hosts.append(host)

    time_end = time.time()
    log.info("Total processing time for %s host(s): %s", len(args.host),
                (time_end - time_start))

    if len(failed_hosts) > 0:
        raise cdist.Error("Failed to deploy to the following hosts: " + 
            " ".join(failed_hosts))

def configinstall_onehost(host, args, mode, parallel):
    """Configure or install ONE remote system"""

    try:
        import cdist.context

        context = cdist.context.Context(
            target_host=host,
            remote_copy=args.remote_copy,
            remote_exec=args.remote_exec,
            initial_manifest=args.manifest,
            base_path=args.cdist_home,
            exec_path=sys.argv[0],
            debug=args.debug)

        c = mode(context)
        c.deploy_and_cleanup()
        context.cleanup()

    except cdist.Error as e:
        # We are running in our own process here, need to sys.exit!
        if parallel:
            log.error(e)
            sys.exit(1)
        else:
            raise

    except KeyboardInterrupt:
        # Ignore in parallel mode, we are existing anyway
        if parallel:
            sys.exit(0)
        # Pass back to controlling code in sequential mode
        else:
            raise

def emulator():
    """Prepare and run emulator"""
    import cdist.emulator
    emulator = cdist.emulator.Emulator(sys.argv)
    return emulator.run()

if __name__ == "__main__":
    # Sys is needed for sys.exit()
    import sys

    cdistpythonversion = '3.2'
    if sys.version < cdistpythonversion:
        print('Cdist requires Python >= ' + cdistpythonversion +
            ' on the source host.', file=sys.stderr)
        sys.exit(1)


    exit_code = 0

    try:
        import logging
        import os
        import re
        import cdist

        log = logging.getLogger("cdist")
        logging.basicConfig(format='%(levelname)s: %(message)s')

        if re.match("__", os.path.basename(sys.argv[0])):
            emulator()
        else:
            commandline()

    except KeyboardInterrupt:
        pass

    except cdist.Error as e:
        log.error(e)
        exit_code = 1

    # Determine exit code by return value of function

    sys.exit(exit_code)
