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


class ObjectTestCase(unittest.TestCase):

    def setUp(self):
        self.cdist_type = cdist.core.Type(type_base_path, '__third')
        self.cdist_object = cdist.core.Object(self.cdist_type, object_base_path, 'moon') 

    def tearDown(self):
        self.cdist_object.changed = False

    def test_name(self):
        self.assertEqual(self.cdist_object.name, '__third/moon')

    def test_object_id(self):
        self.assertEqual(self.cdist_object.object_id, 'moon')

    def test_path(self):
        self.assertEqual(self.cdist_object.path, '__third/moon/.cdist')

    def test_absolute_path(self):
        self.assertEqual(self.cdist_object.absolute_path, os.path.join(object_base_path, '__third/moon/.cdist'))

    def test_code_local_path(self):
        self.assertEqual(self.cdist_object.code_local_path, '__third/moon/.cdist/code-local')

    def test_code_remote_path(self):
        self.assertEqual(self.cdist_object.code_remote_path, '__third/moon/.cdist/code-remote')

    def test_parameter_path(self):
        self.assertEqual(self.cdist_object.parameter_path, '__third/moon/.cdist/parameter')

    def test_explorer_path(self):
        self.assertEqual(self.cdist_object.explorer_path, '__third/moon/.cdist/explorer')

    def test_parameters(self):
        expected_parameters = {'planet': 'Saturn', 'name': 'Prometheus'}
        self.assertEqual(self.cdist_object.parameters, expected_parameters)

    def test_requirements(self):
        expected = []
        self.assertEqual(list(self.cdist_object.requirements), expected)

    def test_changed(self):
        self.assertFalse(self.cdist_object.changed)

    def test_changed_after_changing(self):
        self.cdist_object.changed = True
        self.assertTrue(self.cdist_object.changed)

#suite = unittest.TestLoader().loadTestsFromTestCase(ObjectTestCase)
