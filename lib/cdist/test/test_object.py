# -*- coding: utf-8 -*-
#
# 2010-2011 Steven Armstrong (steven-cdist at armstrong.cc)
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
import tempfile
import unittest
import shutil

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
base_path = op.join(my_dir, 'fixtures')

class ObjectTestCase(unittest.TestCase):
    def setUp(self):
        # FIXME: use defined set of types for testing?
        # FIXME: generate object tree or use predefined?
        self.object_base_dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

'''
suite = unittest.TestLoader().loadTestsFromTestCase(ObjectTestCase)

def suite():
    tests = []
    return unittest.TestSuite(map(ObjectTestCase, tests))
'''
