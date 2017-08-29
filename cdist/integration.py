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
import os
import os.path
import collections


def find_cdist_exec_in_path():
    for path in os.get_exec_path():
        cdist_path = os.path.join(path, 'cdist')
        if os.access(cdist_path, os.X_OK):
            return cdist_path
    return None


_mydir = os.path.dirname(__file__)


def find_cdist_exec():
    cdist_path = os.path.abspath(os.path.join(_mydir, '..', 'scripts',
                                              'cdist'))
    if os.access(cdist_path, os.X_OK):
        return cdist_path
    cdist_path = find_cdist_exec_in_path()
    if not cdist_path:
        raise cdist.Error('Cannot find cdist executable from local lib '
                          'directory: {}, nor in PATH: {}.'.format(
                              _mydir, os.environ.get('PATH')))
    return cdist_path


ACTION_CONFIG = 'config'
ACTION_INSTALL = 'install'


def _process_hosts_simple(action, host, manifest, verbose, cdist_path=None):
    if isinstance(host, str):
        hosts = [host, ]
    elif isinstance(host, collections.Iterable):
        hosts = host
    else:
        raise cdist.Error('Invalid host argument: {}'.format(host))

    # Setup sys.argv[0] since cdist relies on command line invocation.
    if not cdist_path:
        cdist_path = find_cdist_exec()
    sys.argv[0] = cdist_path

    cname = action.title()
    module = getattr(cdist, action)
    theclass = getattr(module, cname)

    # Build argv for cdist - using argparse for argument parsing.
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
                           verbose=cdist.argparse.VERBOSE_INFO,
                           cdist_path=None):
    """Configure hosts with specified manifest using default other cdist
       options. host parameter can be a string or iterbale of hosts.
       cdist_path is path to cdist executable, if it is None then integration
       lib tries to find it.
    """
    _process_hosts_simple(action=ACTION_CONFIG, host=host, manifest=manifest,
                          verbose=verbose, cdist_path=cdist_path)


def install_hosts_simple(host, manifest, verbose=cdist.argparse.VERBOSE_INFO,
                         cdist_path=None):
    """Install hosts with specified manifest using default other cdist
       options. host parameter can be a string or iterbale of hosts.
       cdist_path is path to cdist executable, if it is None then integration
       lib tries to find it.
    """
    _process_hosts_simple(action=ACTION_INSTALL, host=host, manifest=manifest,
                          verbose=verbose, cdist_path=cdist_path)
