# -*- coding: utf-8 -*-
#
# 2010-2011 Steven Armstrong (steven-cdist at armstrong.cc)
# 2012-2015 Nico Schottelius (nico-cdist at schottelius.org)
# 2014      Daniel Heule     (hda at sfs.biz)
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

import io
import os
import shutil
import string
import filecmp
import random

import cdist
from cdist import test
from cdist.exec import local
from cdist import emulator
from cdist import core
from cdist import config

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
conf_dir = op.join(fixtures, 'conf')

class EmulatorTestCase(test.CdistTestCase):

    def setUp(self):
        self.temp_dir = self.mkdtemp()
        handle, self.script = self.mkstemp(dir=self.temp_dir)
        os.close(handle)
        base_path = self.temp_dir

        self.local = local.Local(
            target_host=self.target_host,
            base_path=base_path,
            exec_path=test.cdist_exec_path,
            add_conf_dirs=[conf_dir])
        self.local.create_files_dirs()

        self.manifest = core.Manifest(self.target_host, self.local)
        self.env = self.manifest.env_initial_manifest(self.script)
        self.env['__cdist_object_marker'] = self.local.object_marker_name

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

#    def test_missing_object_marker_variable(self):
#        del self.env['__cdist_object_marker']
#        self.assertRaises(KeyError, emulator.Emulator, argv, env=self.env)

    def test_nonexistent_type_exec(self):
        argv = ['__does-not-exist']
        self.assertRaises(core.cdist_type.NoSuchTypeError, emulator.Emulator, argv, env=self.env)

    def test_nonexistent_type_requirement(self):
        argv = ['__file', '/tmp/foobar']
        self.env['require'] = '__does-not-exist/some-id'
        emu = emulator.Emulator(argv, env=self.env)
        self.assertRaises(core.cdist_type.NoSuchTypeError, emu.run)

    def test_illegal_object_id_requirement(self):
        argv = ['__file', '/tmp/foobar']
        self.env['require'] = "__file/bad/id/with/%s/inside" % self.local.object_marker_name
        emu = emulator.Emulator(argv, env=self.env)
        self.assertRaises(core.IllegalObjectIdError, emu.run)

    def test_missing_object_id_requirement(self):
        argv = ['__file', '/tmp/foobar']
        self.env['require'] = '__file'
        emu = emulator.Emulator(argv, env=self.env)
        self.assertRaises(core.cdist_object.MissingObjectIdError, emu.run)

    def test_no_singleton_no_requirement(self):
        argv = ['__file', '/tmp/foobar']
        self.env['require'] = '__test_singleton'
        emu = emulator.Emulator(argv, env=self.env)
        emu.run()
        # If reached here, everything is fine

    def test_singleton_object_requirement(self):
        argv = ['__file', '/tmp/foobar']
        self.env['require'] = '__issue'
        emu = emulator.Emulator(argv, env=self.env)
        emu.run()
        # if we get here all is fine

    def test_requirement_pattern(self):
        argv = ['__file', '/tmp/foobar']
        self.env['require'] = '__file/etc/*'
        emu = emulator.Emulator(argv, env=self.env)
        # if we get here all is fine

    def test_requirement_via_order_dependency(self):
        self.env['CDIST_ORDER_DEPENDENCY'] = 'on'
        argv = ['__planet', 'erde']
        emu = emulator.Emulator(argv, env=self.env)
        emu.run()
        argv = ['__planet', 'mars']
        emu = emulator.Emulator(argv, env=self.env)
        emu.run()
        # In real world, this is not shared over instances
        del self.env['require']
        argv = ['__file', '/tmp/cdisttest']
        emu = emulator.Emulator(argv, env=self.env)
        emu.run()
        # now load the objects and verify the require parameter of the objects
        cdist_type = core.CdistType(self.local.type_path, '__planet')
        erde_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, 'erde')
        mars_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, 'mars')
        cdist_type = core.CdistType(self.local.type_path, '__file')
        file_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, '/tmp/cdisttest')
        # now test the recorded requirements
        self.assertTrue(len(erde_object.requirements) == 0)
        self.assertEqual(list(mars_object.requirements), ['__planet/erde'])
        self.assertEqual(list(file_object.requirements), ['__planet/mars'])
        # if we get here all is fine


class AutoRequireEmulatorTestCase(test.CdistTestCase):

    def setUp(self):
        self.temp_dir = self.mkdtemp()
        base_path = os.path.join(self.temp_dir, "out")

        self.local = local.Local(
            target_host=self.target_host,
            base_path=base_path,
            exec_path=test.cdist_exec_path,
            add_conf_dirs=[conf_dir])
        self.local.create_files_dirs()
        self.manifest = core.Manifest(self.target_host, self.local)

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def test_autorequire(self):
        initial_manifest = os.path.join(self.local.manifest_path, "init")
        self.manifest.run_initial_manifest(initial_manifest)
        cdist_type = core.CdistType(self.local.type_path, '__saturn')
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, '')
        self.manifest.run_type_manifest(cdist_object)
        expected = ['__planet/Saturn', '__moon/Prometheus']
        self.assertEqual(sorted(cdist_object.autorequire), sorted(expected))

class OverrideTestCase(test.CdistTestCase):

    def setUp(self):
        self.temp_dir = self.mkdtemp()
        handle, self.script = self.mkstemp(dir=self.temp_dir)
        os.close(handle)
        base_path = self.temp_dir

        self.local = local.Local(
            target_host=self.target_host,
            base_path=base_path,
            exec_path=test.cdist_exec_path,
            add_conf_dirs=[conf_dir])
        self.local.create_files_dirs()

        self.manifest = core.Manifest(self.target_host, self.local)
        self.env = self.manifest.env_initial_manifest(self.script)
        self.env['__cdist_object_marker'] = self.local.object_marker_name

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def test_override_negative(self):
        argv = ['__file', '/tmp/foobar']
        emu = emulator.Emulator(argv, env=self.env)
        emu.run()
        argv = ['__file', '/tmp/foobar','--mode','404']
        emu = emulator.Emulator(argv, env=self.env)
        self.assertRaises(cdist.Error, emu.run)

    def test_override_feature(self):
        argv = ['__file', '/tmp/foobar']
        emu = emulator.Emulator(argv, env=self.env)
        emu.run()
        argv = ['__file', '/tmp/foobar','--mode','404']
        self.env['CDIST_OVERRIDE'] = 'on'
        emu = emulator.Emulator(argv, env=self.env)
        emu.run()


class ArgumentsTestCase(test.CdistTestCase):

    def setUp(self):
        self.temp_dir = self.mkdtemp()
        base_path = self.temp_dir
        handle, self.script = self.mkstemp(dir=self.temp_dir)
        os.close(handle)

        self.local = local.Local(
            target_host=self.target_host,
            base_path=base_path,
            exec_path=test.cdist_exec_path,
            add_conf_dirs=[conf_dir])
        self.local.create_files_dirs()

        self.manifest = core.Manifest(self.target_host, self.local)
        self.env = self.manifest.env_initial_manifest(self.script)
        self.env['__cdist_object_marker'] = self.local.object_marker_name

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def test_arguments_with_dashes(self):
        argv = ['__arguments_with_dashes', 'some-id', '--with-dash', 'some value']
        os.environ.update(self.env)
        emu = emulator.Emulator(argv)
        emu.run()

        cdist_type = core.CdistType(self.local.type_path, '__arguments_with_dashes')
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, 'some-id')
        self.assertTrue('with-dash' in cdist_object.parameters)

    def test_boolean(self):
        type_name = '__arguments_boolean'
        object_id = 'some-id'
        argv = [type_name, object_id, '--boolean1']
        os.environ.update(self.env)
        emu = emulator.Emulator(argv)
        emu.run()

        cdist_type = core.CdistType(self.local.type_path, type_name)
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, object_id)
        self.assertTrue('boolean1' in cdist_object.parameters)
        self.assertFalse('boolean2' in cdist_object.parameters)
        # empty file -> True
        self.assertTrue(cdist_object.parameters['boolean1'] == '')

    def test_required_arguments(self):
        """check whether assigning required parameter works"""

        type_name = '__arguments_required'
        object_id = 'some-id'
        value = 'some value'
        argv = [type_name, object_id, '--required1', value, '--required2', value]
        os.environ.update(self.env)
        emu = emulator.Emulator(argv)
        emu.run()

        cdist_type = core.CdistType(self.local.type_path, type_name)
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, object_id)
        self.assertTrue('required1' in cdist_object.parameters)
        self.assertTrue('required2' in cdist_object.parameters)
        self.assertEqual(cdist_object.parameters['required1'], value)
        self.assertEqual(cdist_object.parameters['required2'], value)

#    def test_required_missing(self):
#        type_name = '__arguments_required'
#        object_id = 'some-id'
#        value = 'some value'
#        argv = [type_name, object_id, '--required1', value]
#        os.environ.update(self.env)
#        emu = emulator.Emulator(argv)
#
#        self.assertRaises(SystemExit, emu.run)

    def test_optional(self):
        type_name = '__arguments_optional'
        object_id = 'some-id'
        value = 'some value'
        argv = [type_name, object_id, '--optional1', value]
        os.environ.update(self.env)
        emu = emulator.Emulator(argv)
        emu.run()

        cdist_type = core.CdistType(self.local.type_path, type_name)
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, object_id)
        self.assertTrue('optional1' in cdist_object.parameters)
        self.assertFalse('optional2' in cdist_object.parameters)
        self.assertEqual(cdist_object.parameters['optional1'], value)

    def test_argument_defaults(self):
        type_name = '__argument_defaults'
        object_id = 'some-id'
        value = 'value1'
        argv = [type_name, object_id]
        os.environ.update(self.env)
        emu = emulator.Emulator(argv)
        emu.run()

        cdist_type = core.CdistType(self.local.type_path, type_name)
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, object_id)
        self.assertTrue('optional1' in cdist_object.parameters)
        self.assertFalse('optional2' in cdist_object.parameters)
        self.assertEqual(cdist_object.parameters['optional1'], value)


class StdinTestCase(test.CdistTestCase):

    def setUp(self):
        self.orig_environ = os.environ
        os.environ = os.environ.copy()

        self.temp_dir = self.mkdtemp()
        base_path = os.path.join(self.temp_dir, "out")

        self.local = local.Local(
            target_host=self.target_host,
            base_path=base_path,
            exec_path=test.cdist_exec_path,
            add_conf_dirs=[conf_dir])

        self.local.create_files_dirs()

    def tearDown(self):
        os.environ = self.orig_environ
        shutil.rmtree(self.temp_dir)

    def test_file_from_stdin(self):
        """
        Test whether reading from stdin works
        """

        ######################################################################
        # Create string with random content
        random_string = str(random.sample(range(1000), 800))
        random_buffer = io.BytesIO(bytes(random_string, 'utf-8'))

        ######################################################################
        # Prepare required args and environment for emulator
        type_name = '__file'
        object_id = "cdist-test-id"
        argv = [type_name, object_id]

        env = os.environ.copy()
        env['__cdist_manifest'] = "/cdist-test/path/that/does/not/exist"
        env['__cdist_object_marker'] = self.local.object_marker_name
        env['__cdist_type_base_path'] = self.local.type_path
        env['__global'] = self.local.base_path

        ######################################################################
        # Create path where stdin should reside at
        cdist_type = core.CdistType(self.local.type_path, type_name)
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, object_id)
        stdin_out_path = os.path.join(cdist_object.absolute_path, 'stdin')

        ######################################################################
        # Run emulator
        emu = emulator.Emulator(argv, stdin=random_buffer, env=env)
        emu.run()

        ######################################################################
        # Read where emulator should have placed stdin
        with open(stdin_out_path, 'r') as fd:
            stdin_saved_by_emulator = fd.read()

        self.assertEqual(random_string, stdin_saved_by_emulator)
