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
import getpass
import shutil
import string
import random

import cdist
from cdist import test
from cdist.exec import remote


class RemoteTestCase(test.CdistTestCase):

    def setUp(self):
        self.temp_dir = self.mkdtemp()
        self.target_host = 'localhost'
        self.base_path = self.temp_dir
        user = getpass.getuser()
        remote_exec = "ssh -o User=%s -q" % user
        remote_copy = "scp -o User=%s -q" % user
        self.remote = remote.Remote(self.target_host, self.base_path, remote_exec, remote_copy)

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    ### test api

    def test_conf_path(self):
        self.assertEqual(self.remote.conf_path, os.path.join(self.base_path, "conf"))

    def test_object_path(self):
        self.assertEqual(self.remote.object_path, os.path.join(self.base_path, "object"))

    def test_type_path(self):
        self.assertEqual(self.remote.type_path, os.path.join(self.base_path, "conf", "type"))

    def test_global_explorer_path(self):
        self.assertEqual(self.remote.global_explorer_path, os.path.join(self.base_path, "conf", "explorer"))

    ### /test api

    def test_run_success(self):
        self.remote.run(['/bin/true'])

    def test_run_fail(self):
        self.assertRaises(cdist.Error, self.remote.run, ['/bin/false'])

    def test_run_script_success(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", "/bin/true"])
        self.remote.run_script(script)

    def test_run_script_fail(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", "/bin/false"])
        self.assertRaises(remote.RemoteScriptError, self.remote.run_script, script)

    def test_run_script_get_output(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", "echo foobar"])
        self.assertEqual(self.remote.run_script(script, return_output=True), "foobar\n")

    def test_mkdir(self):
        temp_dir = self.mkdtemp(dir=self.temp_dir)
        os.rmdir(temp_dir)
        self.remote.mkdir(temp_dir)
        self.assertTrue(os.path.isdir(temp_dir))

    def test_rmdir(self):
        temp_dir = self.mkdtemp(dir=self.temp_dir)
        self.remote.rmdir(temp_dir)
        self.assertFalse(os.path.isdir(temp_dir))

    def test_transfer_file(self):
        handle, source = self.mkstemp(dir=self.temp_dir)
        os.close(handle)
        target = self.mkdtemp(dir=self.temp_dir)
        self.remote.transfer(source, target)
        self.assertTrue(os.path.isfile(target))

    def test_transfer_dir(self):
        source = self.mkdtemp(dir=self.temp_dir)
        # put a file in the directory as payload
        handle, source_file = self.mkstemp(dir=source)
        os.close(handle)
        source_file_name = os.path.split(source_file)[-1]
        target = self.mkdtemp(dir=self.temp_dir)
        self.remote.transfer(source, target)
        # test if the payload file is in the target directory
        self.assertTrue(os.path.isfile(os.path.join(target, source_file_name)))

    def test_create_directories(self):
        self.remote.create_directories()
        self.assertTrue(os.path.isdir(self.remote.base_path))
        self.assertTrue(os.path.isdir(self.remote.conf_path))

    def test_run_target_host_in_env(self):
        handle, remote_exec_path = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, 'w') as fd:
            fd.writelines(["#!/bin/sh\n", "echo $__target_host"])
        os.chmod(remote_exec_path, 0o755)
        remote_exec = remote_exec_path
        remote_copy = "echo"
        r = remote.Remote(self.target_host, self.base_path, remote_exec, remote_copy)
        self.assertEqual(r.run('/bin/true', return_output=True), "%s\n" % self.target_host)

    def test_run_script_target_host_in_env(self):
        handle, remote_exec_path = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, 'w') as fd:
            fd.writelines(["#!/bin/sh\n", "echo $__target_host"])
        os.chmod(remote_exec_path, 0o755)
        remote_exec = remote_exec_path
        remote_copy = "echo"
        r = remote.Remote(self.target_host, self.base_path, remote_exec, remote_copy)
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", "/bin/true"])
        self.assertEqual(r.run_script(script, return_output=True), "%s\n" % self.target_host)
