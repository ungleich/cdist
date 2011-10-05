#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2011 Nico Schottelius (nico-cdist at schottelius.org)
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
import os
log = logging.getLogger(__name__)

class Type(object):

    def __init__(self, path, remote_path):
        self.path = path
        self.remote_path = remote_path

    def list_explorers(self):
        """Return list of available explorers"""
        dir = os.path.join(self.path, "explorer")
        if os.path.isdir(dir):
            list = os.listdir(dir)
        else:
            list = []

        log.debug("Explorers for %s in %s: %s", type, dir, list)

        return list

    def is_install(self):
        """Check whether a type is used for installation (if not: for configuration)"""
        return os.path.isfile(os.path.join(self.path, "install"))

    # FIXME: Type
    def type_dir(self, type, *args):
        """Return (sub-)directory of a type"""
        return os.path.join(self.type_base_dir, type, *args)

    # FIXME: Type
    def remote_type_explorer_dir(self, type):
        """Return remote directory that holds the explorers of a type"""
        return os.path.join(REMOTE_TYPE_DIR, type, "explorer")
