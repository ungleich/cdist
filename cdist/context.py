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

import logging
import os
import sys

class Context(object):
    """Hold information about current context"""

    def __init__(self, target_host)

        # Context logging
        self.log = logging.getLogger(self.target_host)
        self.log.addFilter(self)


    def filter(self, record):
        """Add hostname to logs via logging Filter"""

        record.msg = self.target_host + ": " + str(record.msg)

        return True
