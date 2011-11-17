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

from cdist import test
from cdist.exec import local
from cdist import emulator
from cdist import core

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
        self.assertRaises(emulator.IllegalRequirementError, emu.run)

    def test_singleton_object_requirement(self):
        argv = ['__file', '/tmp/foobar']
        os.environ.update(self.env)
        os.environ['require'] = '__issue'
        emu = emulator.Emulator(argv)
        emu.run()
        # if we get here all is fine


import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')

class ArgumentsWithDashesTestCase(test.CdistTestCase):

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

        cdist_type = core.Type(self.local.type_path, '__arguments_with_dashes')
        cdist_object = core.Object(cdist_type, self.local.object_path, 'some-id')
        self.assertTrue('with-dash' in cdist_object.parameters)
