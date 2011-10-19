# -*- coding: utf-8 -*-
#
# 2011 Steven Armstrong (steven-cdist at armstrong.cc)
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
import getpass
import logging

import cdist
from cdist import core
from cdist import test
from cdist.exec import local
from cdist.exec import remote
from cdist.core import code

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
local_base_path = fixtures

class CodeTestCase(test.CdistTestCase):

    def setUp(self):
        self.target_host = 'localhost'

        self.local_base_path = local_base_path
        self.out_path = self.mkdtemp()
        self.local = local.Local(self.target_host, self.local_base_path, self.out_path)
        self.local.create_directories()

        self.remote_base_path = self.mkdtemp()
        self.user = getpass.getuser()
        remote_exec = "ssh -o User=%s -q" % self.user
        remote_copy = "scp -o User=%s -q" % self.user
        self.remote = remote.Remote(self.target_host, self.remote_base_path, remote_exec, remote_copy)

        self.code = code.Code(self.target_host, self.local, self.remote)

        self.cdist_type = core.Type(self.local.type_path, '__dump_environment')
        self.cdist_object = core.Object(self.cdist_type, self.local.object_path, 'whatever')
        self.cdist_object.create()

        self.log = logging.getLogger("cdist")

    def tearDown(self):
        shutil.rmtree(self.out_path)
        shutil.rmtree(self.remote_base_path)

    def test_run_gencode_local_environment(self):
        output_string = self.code.run_gencode_local(self.cdist_object)
        output_dict = {}
        for line in output_string.split('\n'):
            if line:
                junk,value = line.split(': ')
                key = junk.split(' ')[1]
                output_dict[key] = value
        self.assertEqual(output_dict['__target_host'], self.local.target_host)
        self.assertEqual(output_dict['__global'], self.local.out_path)
        self.assertEqual(output_dict['__type'], self.cdist_type.absolute_path)
        self.assertEqual(output_dict['__object'], self.cdist_object.absolute_path)
        self.assertEqual(output_dict['__object_id'], self.cdist_object.object_id)
        self.assertEqual(output_dict['__object_name'], self.cdist_object.name)
        self.assertEqual(output_dict['__self'], self.cdist_object.name)

    def test_run_gencode_remote_environment(self):
        output_string = self.code.run_gencode_remote(self.cdist_object)
        output_dict = {}
        for line in output_string.split('\n'):
            if line:
                junk,value = line.split(': ')
                key = junk.split(' ')[1]
                output_dict[key] = value
        self.assertEqual(output_dict['__target_host'], self.local.target_host)
        self.assertEqual(output_dict['__global'], self.local.out_path)
        self.assertEqual(output_dict['__type'], self.cdist_type.absolute_path)
        self.assertEqual(output_dict['__object'], self.cdist_object.absolute_path)
        self.assertEqual(output_dict['__object_id'], self.cdist_object.object_id)
        self.assertEqual(output_dict['__object_name'], self.cdist_object.name)
        self.assertEqual(output_dict['__self'], self.cdist_object.name)

    def test_transfer_code_remote(self):
        self.cdist_object.code_remote = self.code.run_gencode_remote(self.cdist_object)
        self.code.transfer_code_remote(self.cdist_object)
        destination = os.path.join(self.remote.object_path, self.cdist_object.code_remote_path)
        self.assertTrue(os.path.isfile(destination))

    def test_run_code_local(self):
        self.cdist_object.code_local = self.code.run_gencode_local(self.cdist_object)
        self.code.run_code_local(self.cdist_object)

    def test_run_code_remote_environment(self):
        self.cdist_object.code_remote = self.code.run_gencode_remote(self.cdist_object)
        self.code.transfer_code_remote(self.cdist_object)
        self.code.run_code_remote(self.cdist_object)
