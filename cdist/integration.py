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
import argparse
import sys
import os.path


ACTION_CONFIG = 'config'
ACTION_INSTALL = 'install'


def _process_host(action, host, manifest, verbose):
    cname = action.title()
    module = getattr(cdist, action)
    theclass = getattr(module, cname)

    args = argparse.Namespace()
    args.manifest = manifest
    args.parallel = 0
    args.verbose = verbose
    args.remote_copy = None
    args.remote_exec = None
    args.conf_dir = None
    args.cache_path_pattern = None
    args.quiet = False
    args.all_tagged_hosts = False
    args.beta = False
    args.has_all_tags = False
    args.remote_out_path = None
    args.use_archiving = None
    args.dry_run = False
    args.jobs = None

    cdist.argparse.handle_loglevel(args)
    theclass.construct_remote_exec_copy_patterns(args)

    base_root_path = theclass.create_base_root_path(None)
    host_base_path, hostdir = theclass.create_host_base_dirs(host,
                                                             base_root_path)
    host_tags = None

    # setup sys.argv[0] since cdist relies on command line invocation
    mydir = os.path.dirname(__file__)
    cdist_bin = os.path.abspath(os.path.join(mydir, '..', 'scripts', 'cdist'))
    sys.argv[0] = cdist_bin
    theclass.onehost(host, host_tags, host_base_path, hostdir, args,
                     parallel=args.parallel > 0)


def configure_host(host, manifest, verbose=cdist.argparse.VERBOSE_INFO):
    _process_host(action=ACTION_CONFIG, host=host, manifest=manifest,
                  verbose=verbose)


def install_host(host, manifest, verbose=cdist.argparse.VERBOSE_INFO):
    _process_host(action=ACTION_INSTALL, host=host, manifest=manifest,
                  verbose=verbose)
