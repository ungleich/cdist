# -*- coding: utf-8 -*-
#
# 2010-2011 Steven Armstrong (steven-cdist at armstrong.cc)
# 2011-2013 Nico Schottelius (nico-cdist at schottelius.org)
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

import cdist
from cdist import core
from cdist import test
from cdist.exec import local
from cdist.exec import remote
from cdist.core import explorer

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
conf_dir = op.join(fixtures, "conf")

class ExplorerClassTestCase(test.CdistTestCase):

    def setUp(self):
        self.temp_dir           = self.mkdtemp()
        self.local_path         = os.path.join(self.temp_dir, "local")
        self.remote_base_path   = os.path.join(self.temp_dir, "remote")
        os.makedirs(self.remote_base_path)

        self.local = local.Local(
            target_host=self.target_host,
            base_path=self.local_path,
            exec_path=test.cdist_exec_path,
            add_conf_dirs=[conf_dir],
            )

        self.local.create_files_dirs()

        self.remote = remote.Remote(
            target_host=self.target_host, 
            remote_exec=self.remote_exec,
            remote_copy=self.remote_copy,
            base_path=self.remote_base_path)
        self.remote.create_files_dirs()

        self.explorer = explorer.Explorer(
            self.target_host, 
            self.local, 
            self.remote)

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def test_list_global_explorer_names(self):
        """Ensure that all explorers are listed"""
        names = self.explorer.list_global_explorer_names()
        self.assertIn("foobar", names)
        self.assertIn("global", names)

    def test_transfer_global_explorers(self):
        """Ensure transferring explorers to remote works"""
        self.explorer.transfer_global_explorers()
        source = self.local.global_explorer_path
        destination = self.remote.global_explorer_path
        self.assertEqual(sorted(os.listdir(source)), sorted(os.listdir(destination)))

    def test_run_global_explorer(self):
        """Checkt that running ONE global explorer works"""
        self.explorer.transfer_global_explorers()
        output = self.explorer.run_global_explorer('global')
        self.assertEqual(output, 'global\n')

    def test_global_explorer_output(self):
        """Ensure output is created for every global explorer"""
        out_path = self.mkdtemp()

        self.explorer.run_global_explorers(out_path)
        names = sorted(self.explorer.list_global_explorer_names())
        output = sorted(os.listdir(out_path))

        self.assertEqual(names, output)
        shutil.rmtree(out_path)

    def test_list_type_explorer_names(self):
        cdist_type = core.CdistType(self.local.type_path, '__test_type')
        expected = cdist_type.explorers
        self.assertEqual(self.explorer.list_type_explorer_names(cdist_type), expected)

    def test_transfer_type_explorers(self):
        """Test if transferring type explorers works"""
        cdist_type = core.CdistType(self.local.type_path, '__test_type')
        self.explorer.transfer_type_explorers(cdist_type)
        source = os.path.join(self.local.type_path, cdist_type.explorer_path)
        destination = os.path.join(self.remote.type_path, cdist_type.explorer_path)
        self.assertEqual(os.listdir(source), os.listdir(destination))

    def test_transfer_type_explorers_only_once(self):
        cdist_type = core.CdistType(self.local.type_path, '__test_type')
        # first transfer
        self.explorer.transfer_type_explorers(cdist_type)
        source = os.path.join(self.local.type_path, cdist_type.explorer_path)
        destination = os.path.join(self.remote.type_path, cdist_type.explorer_path)
        self.assertEqual(os.listdir(source), os.listdir(destination))
        # nuke destination folder content, but recreate directory
        shutil.rmtree(destination)
        os.makedirs(destination)
        # second transfer, should not happen
        self.explorer.transfer_type_explorers(cdist_type)
        self.assertFalse(os.listdir(destination))

    def test_transfer_object_parameters(self):
        cdist_type = core.CdistType(self.local.type_path, '__test_type')
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, 'whatever')
        cdist_object.create()
        cdist_object.parameters = {'first': 'first value', 'second': 'second value'}
        self.explorer.transfer_object_parameters(cdist_object)
        source = os.path.join(self.local.object_path, cdist_object.parameter_path)
        destination = os.path.join(self.remote.object_path, cdist_object.parameter_path)
        self.assertEqual(sorted(os.listdir(source)), sorted(os.listdir(destination)))

    def test_run_type_explorer(self):
        cdist_type = core.CdistType(self.local.type_path, '__test_type')
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, 'whatever')
        self.explorer.transfer_type_explorers(cdist_type)
        output = self.explorer.run_type_explorer('world', cdist_object)
        self.assertEqual(output, 'hello\n')

    def test_run_type_explorers(self):
        cdist_type = core.CdistType(self.local.type_path, '__test_type')
        cdist_object = core.CdistObject(cdist_type, self.local.object_path, self.local.object_marker_name, 'whatever')
        cdist_object.create()
        self.explorer.run_type_explorers(cdist_object)
        self.assertEqual(cdist_object.explorers, {'world': 'hello'})
