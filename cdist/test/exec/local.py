# -*- coding: utf-8 -*-
#
# 2010-2011 Steven Armstrong (steven-cdist at armstrong.cc)
# 2012 Nico Schottelius (nico-cdist at schottelius.org)
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
import getpass
import shutil
import string
import random

import cdist
from cdist import test
from cdist.exec import local

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')

class LocalTestCase(test.CdistTestCase):

    def setUp(self):

        target_host = 'localhost'
        self.temp_dir = self.mkdtemp()
        self.out_path = self.temp_dir

        self.local = local.Local(
            target_host=target_host,
            out_path=self.out_path,
            exec_path=test.cdist_exec_path
        )

        self.home_dir = os.path.join(os.environ['HOME'], ".cdist")

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    ### test api

    def test_cache_path(self):
        self.assertEqual(self.local.cache_path, os.path.join(self.home_dir, "cache"))

    def test_global_explorer_path(self):
        self.assertEqual(self.local.global_explorer_path, os.path.join(self.base_path, "conf", "explorer"))

    def test_manifest_path(self):
        self.assertEqual(self.local.manifest_path, os.path.join(self.base_path, "conf", "manifest"))

    def test_type_path(self):
        self.assertEqual(self.local.type_path, os.path.join(self.base_path, "conf", "type"))

    def test_out_path(self):
        self.assertEqual(self.local.out_path, self.out_path)

    def test_bin_path(self):
        self.assertEqual(self.local.bin_path, os.path.join(self.out_path, "bin"))

    def test_global_explorer_out_path(self):
        self.assertEqual(self.local.global_explorer_out_path, os.path.join(self.out_path, "explorer"))

    def test_object_path(self):
        self.assertEqual(self.local.object_path, os.path.join(self.out_path, "object"))

    ### /test api


    def test_run_success(self):
        self.local.run(['/bin/true'])

    def test_run_fail(self):
        self.assertRaises(cdist.Error, self.local.run, ['/bin/false'])

    def test_run_script_success(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", "/bin/true"])
        self.local.run_script(script)

    def test_run_script_fail(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", "/bin/false"])
        self.assertRaises(local.LocalScriptError, self.local.run_script, script)

    def test_run_script_get_output(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", "echo foobar"])
        self.assertEqual(self.local.run_script(script, return_output=True), "foobar\n")

    def test_mkdir(self):
        temp_dir = self.mkdtemp(dir=self.temp_dir)
        os.rmdir(temp_dir)
        self.local.mkdir(temp_dir)
        self.assertTrue(os.path.isdir(temp_dir))

    def test_rmdir(self):
        temp_dir = self.mkdtemp(dir=self.temp_dir)
        self.local.rmdir(temp_dir)
        self.assertFalse(os.path.isdir(temp_dir))

    def test_create_files_dirs(self):
        self.local.create_files_dirs()
        self.assertTrue(os.path.isdir(self.local.out_path))
        self.assertTrue(os.path.isdir(self.local.bin_path))
        self.assertTrue(os.path.isdir(self.local.conf_path))
