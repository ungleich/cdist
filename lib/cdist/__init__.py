# -*- coding: utf-8 -*-
#
# 2010-2011 Nico Schottelius (nico-cdist at schottelius.org)
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

VERSION     = "2.0.3"

class Error(Exception):
    """Base exception class for this project"""
    pass


class MissingEnvironmentVariableError(Error):
    """Raised when a required environment variable is not set."""

    def __init__(self, name):
        self.name = name

    def __str__(self):
        return 'Missing required environment variable: {0.name}'.format(o)
