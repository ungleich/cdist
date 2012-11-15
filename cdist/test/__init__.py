# -*- coding: utf-8 -*-
#
# 2011-2012 Nico Schottelius (nico-cdist at schottelius.org)
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
import unittest
import tempfile

cdist_base_path = os.path.abspath(
    os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../"))

cdist_exec_path = os.path.join(cdist_base_path, "scripts/cdist")

global_fixtures_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "fixtures"))

class CdistTestCase(unittest.TestCase):

    remote_exec = os.path.join(global_fixtures_dir, "remote", "exec")
    remote_copy = os.path.join(global_fixtures_dir, "remote", "copy")

    target_host = 'cdisttesthost'

    def mkdtemp(self, **kwargs):
        return tempfile.mkdtemp(prefix='tmp.cdist.test.', **kwargs)

    def mkstemp(self, **kwargs):
        return tempfile.mkstemp(prefix='tmp.cdist.test.', **kwargs)
