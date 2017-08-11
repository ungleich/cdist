#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2017 Darko Poljak (darko.poljak at gmail.com)
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

import cdist
import cdist.log
import cdist.config
import cdist.install
import cdist.argparse
import sys
import os.path
import collections


ACTION_CONFIG = 'config'
ACTION_INSTALL = 'install'


def _process_hosts_simple(action, host, manifest, verbose):
    if isinstance(host, str):
        hosts = [host, ]
    elif isinstance(host, collections.Iterable):
        hosts = host
    else:
        raise cdist.Error('Invalid host argument: {}'.format(host))

    # setup sys.argv[0] since cdist relies on command line invocation
    mydir = os.path.dirname(__file__)
    cdist_bin = os.path.abspath(os.path.join(mydir, '..', 'scripts', 'cdist'))
    sys.argv[0] = cdist_bin

    cname = action.title()
    module = getattr(cdist, action)
    theclass = getattr(module, cname)

    argv = [action, '-i', manifest, ]
    for i in range(verbose):
        argv.append('-v')
    for x in hosts:
        argv.append(x)

    parser = cdist.argparse.get_parsers()
    args = parser['main'].parse_args(argv)
    cdist.argparse.handle_loglevel(args)

    theclass.construct_remote_exec_copy_patterns(args)
    base_root_path = theclass.create_base_root_path(None)

    for target_host in args.host:
        host_base_path, hostdir = theclass.create_host_base_dirs(
            target_host, base_root_path)
        theclass.onehost(target_host, None, host_base_path, hostdir, args,
                         parallel=False)


def configure_hosts_simple(host, manifest,
                           verbose=cdist.argparse.VERBOSE_INFO):
    _process_hosts_simple(action=ACTION_CONFIG, host=host, manifest=manifest,
                          verbose=verbose)


def install_hosts_simple(host, manifest, verbose=cdist.argparse.VERBOSE_INFO):
    _process_hosts_simple(action=ACTION_INSTALL, host=host, manifest=manifest,
                          verbose=verbose)
