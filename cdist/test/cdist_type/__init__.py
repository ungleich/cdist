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

from cdist import test
from cdist import core

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')


class TypeTestCase(test.CdistTestCase):

    def test_list_type_names(self):
        base_path = op.join(fixtures, 'list_types')
        type_names = core.CdistType.list_type_names(base_path)
        self.assertEqual(sorted(type_names), ['__first', '__second', '__third'])

    def test_list_types(self):
        base_path = op.join(fixtures, 'list_types')
        types = list(core.CdistType.list_types(base_path))
        types_expected = [
            core.CdistType(base_path, '__first'),
            core.CdistType(base_path, '__second'),
            core.CdistType(base_path, '__third'),
        ]
        self.assertEqual(sorted(types), types_expected)

    def test_only_one_instance(self):
        base_path = fixtures
        cdist_type1 = core.CdistType(base_path, '__name_path')
        cdist_type2 = core.CdistType(base_path, '__name_path')
        self.assertEqual(id(cdist_type1), id(cdist_type2))

    def test_nonexistent_type(self):
        base_path = fixtures
        self.assertRaises(core.NoSuchTypeError, core.CdistType, base_path, '__i-dont-exist')

    def test_name(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__name_path')
        self.assertEqual(cdist_type.name, '__name_path')

    def test_path(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__name_path')
        self.assertEqual(cdist_type.path, '__name_path')

    def test_base_path(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__name_path')
        self.assertEqual(cdist_type.base_path, base_path)

    def test_absolute_path(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__name_path')
        self.assertEqual(cdist_type.absolute_path, os.path.join(base_path, '__name_path'))

    def test_manifest_path(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__name_path')
        self.assertEqual(cdist_type.manifest_path, os.path.join('__name_path', 'manifest'))

    def test_explorer_path(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__name_path')
        self.assertEqual(cdist_type.explorer_path, os.path.join('__name_path', 'explorer'))

    def test_gencode_local_path(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__name_path')
        self.assertEqual(cdist_type.gencode_local_path, os.path.join('__name_path', 'gencode-local'))

    def test_gencode_remote_path(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__name_path')
        self.assertEqual(cdist_type.gencode_remote_path, os.path.join('__name_path', 'gencode-remote'))

    def test_singleton_is_singleton(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__singleton')
        self.assertTrue(cdist_type.is_singleton)

    def test_not_singleton_is_singleton(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__not_singleton')
        self.assertFalse(cdist_type.is_singleton)

    def test_with_explorers(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__with_explorers')
        self.assertEqual(cdist_type.explorers, ['whatever'])

    def test_without_explorers(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__without_explorers')
        self.assertEqual(cdist_type.explorers, [])

    def test_with_required_parameters(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__with_required_parameters')
        self.assertEqual(cdist_type.required_parameters, ['required1', 'required2'])

    def test_without_required_parameters(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__without_required_parameters')
        self.assertEqual(cdist_type.required_parameters, [])

    def test_with_optional_parameters(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__with_optional_parameters')
        self.assertEqual(cdist_type.optional_parameters, ['optional1', 'optional2'])

    def test_without_optional_parameters(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__without_optional_parameters')
        self.assertEqual(cdist_type.optional_parameters, [])

    def test_with_boolean_parameters(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__with_boolean_parameters')
        self.assertEqual(cdist_type.boolean_parameters, ['boolean1', 'boolean2'])

    def test_without_boolean_parameters(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__without_boolean_parameters')
        self.assertEqual(cdist_type.boolean_parameters, [])

    def test_with_parameter_defaults(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__with_parameter_defaults')
        self.assertTrue('optional1' in cdist_type.parameter_defaults)
        self.assertFalse('optional2' in cdist_type.parameter_defaults)
        self.assertEqual(cdist_type.parameter_defaults['optional1'], 'value1')

    def test_directory_in_default(self):
        base_path = fixtures
        cdist_type = core.CdistType(base_path, '__directory_in_default')
        self.assertEqual(
            list(sorted(cdist_type.parameter_defaults.keys())),
            ['bar', 'foo']
        )
