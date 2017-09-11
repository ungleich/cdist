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

import os
import logging


def listdir(path='.', include_dot=False):
    """os.listdir but do not include entries whose names begin with a dot('.')
       if include_dot is False.
    """
    if include_dot:
        return os.listdir(path)
    else:
        return [x for x in os.listdir(path) if not _ishidden(x)]


def _ishidden(path):
    return path[0] in ('.', b'.'[0])


def log_level_env_var_val(log):
    return str(log.getEffectiveLevel())


def log_level_name_env_var_val(log):
    return logging.getLevelName(log.getEffectiveLevel())
