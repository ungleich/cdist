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

import cdist.core

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
object_base_path = op.join(fixtures, 'object')
type_base_path = op.join(fixtures, 'type')

class ObjectClassTestCase(unittest.TestCase):

    def test_list_object_names(self):
        object_names = list(cdist.core.Object.list_object_names(object_base_path))
        self.assertEqual(object_names, ['__first/man', '__second/on-the', '__third/moon'])

    def test_list_type_names(self):
        type_names = list(cdist.core.Object.list_type_names(object_base_path))
        self.assertEqual(type_names, ['__first', '__second', '__third'])

    def test_list_objects(self):
        objects = list(cdist.core.Object.list_objects(object_base_path, type_base_path))
        objects_expected = [
            cdist.core.Object(cdist.core.Type(type_base_path, '__first'), object_base_path, 'man'),
            cdist.core.Object(cdist.core.Type(type_base_path, '__second'), object_base_path, 'on-the'),
            cdist.core.Object(cdist.core.Type(type_base_path, '__third'), object_base_path, 'moon'),
        ]
        self.assertEqual(objects, objects_expected)


'''
suite = unittest.TestLoader().loadTestsFromTestCase(ObjectTestCase)

def suite():
    tests = []
    return unittest.TestSuite(map(ObjectTestCase, tests))
'''
