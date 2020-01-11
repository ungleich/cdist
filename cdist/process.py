#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2020 Darko Poljak (darko.poljak at gmail.com)
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

import os
import sys
import importlib
import re
import cdist


PROCESS_PARENT = 'process'
_PROCESS_DEBUG = os.environ.get('CDIST_PROCESS_DEBUG', None)
if _PROCESS_DEBUG:
    def _debug(msg):
        print('[cdist process debug] {}'.format(msg))
else:
    def _debug(msg):
        pass


_process_path = []

_env_path = os.environ.get('CDIST_PROCESS_PATH', None)
if _env_path:
    for x in re.split(r'(?<!\\):', _env_path):
        if x:
            _debug('Adding CDIST_PROCESS_PATH {}'.format(x))
            _process_path.append(x)
_home_dir = cdist.home_dir()
if _home_dir:
    _debug('Adding cdist home dir process path {}'.format(_home_dir))
    _process_path.append(_home_dir)


def _scan_processes():
    for path in _process_path:
        process_path = os.path.join(path, PROCESS_PARENT)
        for fname in os.listdir(process_path):
            entry = os.path.join(process_path, fname)
            if not os.path.isdir(entry):
                continue
            _debug('Scanning {}'.format(entry))
            pfile = os.path.join(entry, '__init__.py')
            _debug('Scanning {}'.format(pfile))
            if os.path.exists(pfile):
                _debug('Found process in {}: {}'.format(entry, pfile))
                yield entry


def setup(parent_parser):
    for entry in _scan_processes():
        mod_name = os.path.basename(entry)
        mod_dir = os.path.dirname(entry)
        sys.path.insert(0, mod_dir)
        proc_mod = importlib.import_module(mod_name)
        _debug('Registering process module {} from {}'.format(
            mod_name, entry))
        proc_mod.register(parent_parser)


def commandline(args, parser):
    parser.print_help()
