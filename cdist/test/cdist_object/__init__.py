# -*- coding: utf-8 -*-
#
# 2010-2011 Steven Armstrong (steven-cdist at armstrong.cc)
# 2012-2015 Nico Schottelius (nico-cdist at schottelius.org)
# 2014 Daniel Heule     (hda at sfs.biz)
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
import shutil
import tempfile

from cdist import test
from cdist import core

import cdist

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
type_base_path = op.join(fixtures, 'type')

OBJECT_MARKER_NAME = '.cdist-pseudo-random'

expected_object_names = sorted([
    '__first/child',
    '__first/dog',
    '__first/man',
    '__first/woman',
    '__second/on-the',
    '__second/under-the',
    '__third/moon'])


class ObjectClassTestCase(test.CdistTestCase):

    def setUp(self):

        self.tempdir = tempfile.mkdtemp(prefix="cdist.test")
        self.object_base_path = self.tempdir

        self.expected_objects = []
        for cdist_object_name in expected_object_names:
            cdist_type, cdist_object_id = cdist_object_name.split("/", 1)
            cdist_object = core.CdistObject(core.CdistType(type_base_path, cdist_type), self.object_base_path,
                OBJECT_MARKER_NAME, cdist_object_id)
            cdist_object.create()
            self.expected_objects.append(cdist_object)
 
    def tearDown(self):
        shutil.rmtree(self.tempdir)

    def test_list_object_names(self):
       found_object_names = sorted(list(core.CdistObject.list_object_names(self.object_base_path, OBJECT_MARKER_NAME)))
       self.assertEqual(found_object_names, expected_object_names)

    def test_list_type_names(self):
        type_names = list(cdist.core.CdistObject.list_type_names(self.object_base_path))
        self.assertEqual(sorted(type_names), ['__first', '__second', '__third'])

    def test_list_objects(self):
        found_objects = sorted(list(core.CdistObject.list_objects(self.object_base_path, type_base_path, OBJECT_MARKER_NAME)))
        self.assertEqual(found_objects, self.expected_objects)

    def test_create_singleton(self):
        """Check whether creating an object without id (singleton) works"""
        singleton = self.expected_objects[0].object_from_name("__test_singleton")
        # came here - everything fine

    def test_create_singleton_not_singleton_type(self):
        """try to create an object of a type that is not a singleton
           without an object id"""
        with self.assertRaises(cdist.core.cdist_object.MissingObjectIdError):
            self.expected_objects[0].object_from_name("__first")

class ObjectIdTestCase(test.CdistTestCase):

    def setUp(self):
        self.tempdir = tempfile.mkdtemp(prefix="cdist.test")
        self.object_base_path = self.tempdir

        self.expected_objects = []
        for cdist_object_name in expected_object_names:
            cdist_type, cdist_object_id = cdist_object_name.split("/", 1)
            cdist_object = core.CdistObject(core.CdistType(type_base_path, cdist_type), self.object_base_path,
                OBJECT_MARKER_NAME, cdist_object_id)
            cdist_object.create()
            self.expected_objects.append(cdist_object)
 
    def tearDown(self):
        shutil.rmtree(self.tempdir)

    def test_object_id_contains_double_slash(self):
        cdist_type = core.CdistType(type_base_path, '__third')
        illegal_object_id = '/object_id//may/not/contain/double/slash'
        with self.assertRaises(core.IllegalObjectIdError):
            core.CdistObject(cdist_type, self.object_base_path, OBJECT_MARKER_NAME, illegal_object_id)

    def test_object_id_contains_object_marker(self):
        cdist_type = core.CdistType(type_base_path, '__third')
        illegal_object_id = 'object_id/may/not/contain/%s/anywhere' % OBJECT_MARKER_NAME
        with self.assertRaises(core.IllegalObjectIdError):
            core.CdistObject(cdist_type, self.object_base_path, OBJECT_MARKER_NAME, illegal_object_id)

    def test_object_id_contains_object_marker_string(self):
        cdist_type = core.CdistType(type_base_path, '__third')
        illegal_object_id = 'object_id/may/contain_%s_in_filename' % OBJECT_MARKER_NAME
        core.CdistObject(cdist_type, self.object_base_path, OBJECT_MARKER_NAME, illegal_object_id)
        # if we get here, the test passed

    def test_object_id_contains_only_dot(self):
        cdist_type = core.CdistType(type_base_path, '__third')
        illegal_object_id = '.'
        with self.assertRaises(core.IllegalObjectIdError):
            core.CdistObject(cdist_type, self.object_base_path, OBJECT_MARKER_NAME, illegal_object_id)

    def test_object_id_on_singleton_type(self):
        cdist_type = core.CdistType(type_base_path, '__test_singleton')
        illegal_object_id = 'object_id'
        with self.assertRaises(core.IllegalObjectIdError):
            core.CdistObject(cdist_type, self.object_base_path, OBJECT_MARKER_NAME, illegal_object_id)

class ObjectTestCase(test.CdistTestCase):

    def setUp(self):
        self.tempdir = tempfile.mkdtemp(prefix="cdist.test")
        self.object_base_path = self.tempdir

        self.cdist_type = core.CdistType(type_base_path, '__third')
        self.cdist_object = core.CdistObject(self.cdist_type, self.object_base_path, OBJECT_MARKER_NAME, 'moon') 
        self.cdist_object.create()

        self.cdist_object.parameters['planet'] = 'Saturn'
        self.cdist_object.parameters['name'] = 'Prometheus'


    def tearDown(self):
        self.cdist_object.prepared = False
        self.cdist_object.ran = False
        self.cdist_object.source = []
        self.cdist_object.code_local = ''
        self.cdist_object.code_remote = ''
        self.cdist_object.state = ''

        shutil.rmtree(self.tempdir)

    def test_name(self):
        self.assertEqual(self.cdist_object.name, '__third/moon')

    def test_object_id(self):
        self.assertEqual(self.cdist_object.object_id, 'moon')

    def test_path(self):
        self.assertEqual(self.cdist_object.path, "__third/moon/%s" % OBJECT_MARKER_NAME)

    def test_absolute_path(self):
        self.assertEqual(self.cdist_object.absolute_path, os.path.join(self.object_base_path, "__third/moon/%s" % OBJECT_MARKER_NAME))

    def test_code_local_path(self):
        self.assertEqual(self.cdist_object.code_local_path, "__third/moon/%s/code-local" % OBJECT_MARKER_NAME)

    def test_code_remote_path(self):
        self.assertEqual(self.cdist_object.code_remote_path, "__third/moon/%s/code-remote" % OBJECT_MARKER_NAME)

    def test_parameter_path(self):
        self.assertEqual(self.cdist_object.parameter_path, "__third/moon/%s/parameter" % OBJECT_MARKER_NAME)

    def test_explorer_path(self):
        self.assertEqual(self.cdist_object.explorer_path, "__third/moon/%s/explorer" % OBJECT_MARKER_NAME)

    def test_parameters(self):
        expected_parameters = {'planet': 'Saturn', 'name': 'Prometheus'}
        self.assertEqual(self.cdist_object.parameters, expected_parameters)

    def test_explorers(self):
        self.assertEqual(self.cdist_object.explorers, {})

    # FIXME: actually testing fsproperty.DirectoryDictProperty here, move to their own test case
    def test_explorers_assign_dict(self):
        expected = {'first': 'foo', 'second': 'bar'}
        # when set, written to file
        self.cdist_object.explorers = expected
        object_explorer_path = os.path.join(self.cdist_object.base_path, self.cdist_object.explorer_path)
        self.assertTrue(os.path.isdir(object_explorer_path))
        # when accessed, read from file
        self.assertEqual(self.cdist_object.explorers, expected)
        # remove dynamically created folder
        self.cdist_object.explorers = {}
        os.rmdir(os.path.join(self.cdist_object.base_path, self.cdist_object.explorer_path))

    # FIXME: actually testing fsproperty.DirectoryDictProperty here, move to their own test case
    def test_explorers_assign_key_value(self):
        expected = {'first': 'foo', 'second': 'bar'}
        object_explorer_path = os.path.join(self.cdist_object.base_path, self.cdist_object.explorer_path)
        for key,value in expected.items():
            # when set, written to file
            self.cdist_object.explorers[key] = value
            self.assertTrue(os.path.isfile(os.path.join(object_explorer_path, key)))
        # when accessed, read from file
        self.assertEqual(self.cdist_object.explorers, expected)
        # remove dynamically created folder
        self.cdist_object.explorers = {}
        os.rmdir(os.path.join(self.cdist_object.base_path, self.cdist_object.explorer_path))

    def test_requirements(self):
        expected = []
        self.assertEqual(list(self.cdist_object.requirements), expected)

    def test_state(self):
        self.assertEqual(self.cdist_object.state, '')

    def test_state_prepared(self):
        self.cdist_object.state = core.CdistObject.STATE_PREPARED
        self.assertEqual(self.cdist_object.state, core.CdistObject.STATE_PREPARED)

    def test_state_running(self):
        self.cdist_object.state = core.CdistObject.STATE_RUNNING
        self.assertEqual(self.cdist_object.state, core.CdistObject.STATE_RUNNING)

    def test_state_done(self):
        self.cdist_object.state = core.CdistObject.STATE_DONE
        self.assertEqual(self.cdist_object.state, core.CdistObject.STATE_DONE)

    def test_source(self):
        self.assertEqual(list(self.cdist_object.source), [])

    def test_source_after_changing(self):
        self.cdist_object.source = ['/path/to/manifest']
        self.assertEqual(list(self.cdist_object.source), ['/path/to/manifest'])

    def test_code_local(self):
        self.assertEqual(self.cdist_object.code_local, '')

    def test_code_local_after_changing(self):
        self.cdist_object.code_local = 'Hello World'
        self.assertEqual(self.cdist_object.code_local, 'Hello World')

    def test_code_remote(self):
        self.assertEqual(self.cdist_object.code_remote, '')

    def test_code_remote_after_changing(self):
        self.cdist_object.code_remote = 'Hello World'
        self.assertEqual(self.cdist_object.code_remote, 'Hello World')

    def test_object_from_name(self):
        self.cdist_object.code_remote = 'Hello World'
        other_name = '__first/man'
        other_object = self.cdist_object.object_from_name(other_name)
        self.assertTrue(isinstance(other_object, core.CdistObject))
        self.assertEqual(other_object.cdist_type.name, '__first')
        self.assertEqual(other_object.object_id, 'man')
