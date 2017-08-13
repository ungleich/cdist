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

import fcntl
import logging
import os


log = logging.getLogger('cdist-flock')


class Flock():
    def __init__(self, path):
        self.path = path
        self.lockfd = None

    def flock(self):
        log.debug('Acquiring lock on %s', self.path)
        self.lockfd = open(self.path, 'w+')
        fcntl.flock(self.lockfd, fcntl.LOCK_EX)
        log.debug('Acquired lock on %s', self.path)

    def funlock(self):
        log.debug('Releasing lock on %s', self.path)
        fcntl.flock(self.lockfd, fcntl.LOCK_UN)
        self.lockfd.close()
        self.lockfd = None
        try:
            os.remove(self.path)
        except FileNotFoundError:
            pass
        log.debug('Released lock on %s', self.path)

    def __enter__(self):
        self.flock()
        return self

    def __exit__(self, *args):
        self.funlock()
        return False
