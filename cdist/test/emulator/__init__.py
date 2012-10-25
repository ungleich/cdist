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
import cdist.context

local_base_path = test.cdist_base_path

class EmulatorTestCase(test.CdistTestCase):

    def setUp(self):
        self.orig_environ = os.environ
        os.environ = os.environ.copy()
        self.temp_dir = self.mkdtemp()
        handle, self.script = self.mkstemp(dir=self.temp_dir)
        os.close(handle)
        self.target_host = 'localhost'
        out_path = self.temp_dir
        self.local = local.Local(self.target_host, local_base_path, out_path)
        self.local.create_directories()
        self.env = {
            'PATH': "%s:%s" % (self.local.bin_path, os.environ['PATH']),
            '__target_host': self.target_host,
            '__global': self.local.out_path,
            '__cdist_type_base_path': self.local.type_path, # for use in type emulator
            '__manifest': self.local.manifest_path,
            '__cdist_manifest': self.script,
        }

    def tearDown(self):
        os.environ = self.orig_environ
        shutil.rmtree(self.temp_dir)

    def test_nonexistent_type_exec(self):
        argv = ['__does-not-exist']
        os.environ.update(self.env)
        self.assertRaises(core.NoSuchTypeError, emulator.Emulator, argv)

    def test_nonexistent_type_requirement(self):
        argv = ['__file', '/tmp/foobar']
        os.environ.update(self.env)
        os.environ['require'] = '__does-not-exist/some-id'
        emu = emulator.Emulator(argv)
        self.assertRaises(core.NoSuchTypeError, emu.run)

    def test_illegal_object_id_requirement(self):
        argv = ['__file', '/tmp/foobar']
        os.environ.update(self.env)
        os.environ['require'] = '__file/bad/id/with/.cdist/inside'
        emu = emulator.Emulator(argv)
        self.assertRaises(core.IllegalObjectIdError, emu.run)

    def test_missing_object_id_requirement(self):
        argv = ['__file', '/tmp/foobar']
        os.environ.update(self.env)
        os.environ['require'] = '__file'
        emu = emulator.Emulator(argv)
        self.assertRaises(core.IllegalObjectIdError, emu.run)

    def test_singleton_object_requirement(self):
        argv = ['__file', '/tmp/foobar']
        os.environ.update(self.env)
        os.environ['require'] = '__issue'
        emu = emulator.Emulator(argv)
        emu.run()
        # if we get here all is fine

    def test_requirement_pattern(self):
        argv = ['__file', '/tmp/foobar']
        os.environ.update(self.env)
        os.environ['require'] = '__file/etc/*'
        emu = emulator.Emulator(argv)
        # if we get here all is fine


import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')

class AutoRequireEmulatorTestCase(test.CdistTestCase):

    def setUp(self):
        self.temp_dir = self.mkdtemp()
        self.target_host = 'localhost'
        out_path = self.temp_dir
        _local_base_path = fixtures
        self.local = local.Local(self.target_host, _local_base_path, out_path)
        self.local.create_directories()
        self.local.link_emulator(cdist.test.cdist_exec_path)
        self.manifest = core.Manifest(self.target_host, self.local)

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def test_autorequire(self):
        initial_manifest = os.path.join(self.local.manifest_path, "init")
        self.manifest.run_initial_manifest(initial_manifest)
        cdist_type = core.CdistType(self.local.type_path, '__saturn')
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, 'singleton')
        self.manifest.run_type_manifest(cdist_object)
        expected = ['__planet/Saturn', '__moon/Prometheus']
        self.assertEqual(sorted(cdist_object.autorequire), sorted(expected))


class ArgumentsTestCase(test.CdistTestCase):

    def setUp(self):
        self.temp_dir = self.mkdtemp()
        self.target_host = 'localhost'
        out_path = self.temp_dir
        handle, self.script = self.mkstemp(dir=self.temp_dir)
        os.close(handle)
        _local_base_path = fixtures
        self.local = local.Local(self.target_host, _local_base_path, out_path)
        self.local.create_directories()
        self.local.link_emulator(test.cdist_exec_path)
        self.env = {
            'PATH': "%s:%s" % (self.local.bin_path, os.environ['PATH']),
            '__target_host': self.target_host,
            '__global': self.local.out_path,
            '__cdist_type_base_path': self.local.type_path, # for use in type emulator
            '__manifest': self.local.manifest_path,
            '__cdist_manifest': self.script,
        }

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def test_arguments_with_dashes(self):
        argv = ['__arguments_with_dashes', 'some-id', '--with-dash', 'some value']
        os.environ.update(self.env)
        emu = emulator.Emulator(argv)
        emu.run()

        cdist_type = core.CdistType(self.local.type_path, '__arguments_with_dashes')
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, 'some-id')
        self.assertTrue('with-dash' in cdist_object.parameters)

    def test_boolean(self):
        type_name = '__arguments_boolean'
        object_id = 'some-id'
        argv = [type_name, object_id, '--boolean1']
        os.environ.update(self.env)
        emu = emulator.Emulator(argv)
        emu.run()

        cdist_type = core.CdistType(self.local.type_path, type_name)
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, object_id)
        self.assertTrue('boolean1' in cdist_object.parameters)
        self.assertFalse('boolean2' in cdist_object.parameters)
        # empty file -> True
        self.assertTrue(cdist_object.parameters['boolean1'] == '')

    def test_required(self):
        type_name = '__arguments_required'
        object_id = 'some-id'
        value = 'some value'
        argv = [type_name, object_id, '--required1', value, '--required2', value]
        os.environ.update(self.env)
        emu = emulator.Emulator(argv)
        emu.run()

        cdist_type = core.CdistType(self.local.type_path, type_name)
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, object_id)
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
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, object_id)
        self.assertTrue('optional1' in cdist_object.parameters)
        self.assertFalse('optional2' in cdist_object.parameters)
        self.assertEqual(cdist_object.parameters['optional1'], value)


class StdinTestCase(test.CdistTestCase):

    def setUp(self):
        self.orig_environ = os.environ
        os.environ = os.environ.copy()
        self.target_host = 'localhost'
        self.temp_dir = self.mkdtemp()
        os.environ['__cdist_out_dir'] = self.temp_dir
        local_base_path = fixtures

        self.context = cdist.context.Context(
            target_host=self.target_host,
            remote_copy='scp -o User=root -q',
            remote_exec='ssh -o User=root -q',
            base_path=local_base_path,
            exec_path=test.cdist_exec_path,
            debug=False)
        self.config = config.Config(self.context)

    def tearDown(self):
        os.environ = self.orig_environ
        shutil.rmtree(self.temp_dir)

    def test_file_from_stdin(self):
        handle, destination = self.mkstemp(dir=self.temp_dir)
        os.close(handle)
        source_handle, source = self.mkstemp(dir=self.temp_dir)
        candidates = string.ascii_letters+string.digits
        with os.fdopen(source_handle, 'w') as fd:
            for x in range(100):
                fd.write(''.join(random.sample(candidates, len(candidates))))

        handle, initial_manifest = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, 'w') as fd:
            fd.write('__file_from_stdin %s --source %s\n' % (destination, source))
        self.context.initial_manifest = initial_manifest
        self.config.stage_prepare()

        cdist_type = core.CdistType(self.config.local.type_path, '__file')
        cdist_object = core.CdistObject(cdist_type, self.config.local.object_path, destination)
        # Test weither stdin has been stored correctly
        self.assertTrue(filecmp.cmp(source, os.path.join(cdist_object.absolute_path, 'stdin')))
