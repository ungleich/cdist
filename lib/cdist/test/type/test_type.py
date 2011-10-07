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


class TypeTestCase(unittest.TestCase):
    def setUp(self):
        # FIXME: use defined set of types for testing?
        # FIXME: generate object tree or use predefined?
        self.temp_dir = tempfile.mkdtemp()
        self.object_base_path = op.join(self.temp_dir, '')

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def test_singleton_is_singleton(self):
        base_path = fixtures
        cdist_type = cdist.core.Type(base_path, '__singleton')
        self.assertTrue(cdist_type.is_singleton)

    def test_not_singleton_is_singleton(self):
        base_path = fixtures
        cdist_type = cdist.core.Type(base_path, '__not_singleton')
        self.assertFalse(cdist_type.is_singleton)

    def test_install_is_install(self):
        base_path = fixtures
        cdist_type = cdist.core.Type(base_path, '__install')
        self.assertTrue(cdist_type.is_install)

    def test_not_install_is_install(self):
        base_path = fixtures
        cdist_type = cdist.core.Type(base_path, '__not_install')
        self.assertFalse(cdist_type.is_install)

    def test_with_explorers(self):
        base_path = fixtures
        cdist_type = cdist.core.Type(base_path, '__with_explorers')
        self.assertEqual(cdist_type.explorers, ['whatever'])

    def test_without_explorers(self):
        base_path = fixtures
        cdist_type = cdist.core.Type(base_path, '__without_explorers')
        self.assertEqual(cdist_type.explorers, [])


'''
suite = unittest.TestLoader().loadTestsFromTestCase(ObjectTestCase)

def suite():
    tests = []
    return unittest.TestSuite(map(ObjectTestCase, tests))
'''
