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

import unittest
import os
import tempfile
import getpass
import shutil
import string
import random

import cdist
from cdist.exec import remote


class RemoteTestCase(unittest.TestCase):

    def mkdtemp(self, **kwargs):
        return tempfile.mkdtemp(prefix='tmp.cdist.test.', **kwargs)

    def mkstemp(self, **kwargs):
        return tempfile.mkstemp(prefix='tmp.cdist.test.', **kwargs)

    def setUp(self):
        self.temp_dir = self.mkdtemp()
        target_host = 'localhost'
        remote_base_path = self.temp_dir
        user = getpass.getuser()
        remote_exec = "ssh -o User=%s -q" % user
        remote_copy = "scp -o User=%s -q" % user
        self.remote = remote.Remote(target_host, remote_base_path, remote_exec, remote_copy)

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def test_run_success(self):
        self.remote.run(['/bin/true'])

    def test_run_fail(self):
        self.assertRaises(cdist.Error, self.remote.run, ['/bin/false'])

    def test_run_script_success(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        fd = open(script, "w")
        fd.writelines(["#!/bin/sh\n", "/bin/true"])
        fd.close()
        self.remote.run_script(script)

    def test_run_script_fail(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        fd = open(script, "w")
        fd.writelines(["#!/bin/sh\n", "/bin/false"])
        fd.close()
        self.assertRaises(remote.RemoteScriptError, self.remote.run_script, script)

    def test_run_script_get_output(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        fd = open(script, "w")
        fd.writelines(["#!/bin/sh\n", "echo foobar"])
        fd.close()
        self.assertEqual(self.remote.run_script(script), b"foobar\n")

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
        target = self.mkdtemp(dir=self.temp_dir)
        self.remote.transfer(source, target)
        self.assertTrue(os.path.isfile(target))

    def test_transfer_dir(self):
        source = self.mkdtemp(dir=self.temp_dir)
        # put a file in the directory as payload
        handle, source_file = self.mkstemp(dir=source)
        source_file_name = os.path.split(source_file)[-1]
        target = self.mkdtemp(dir=self.temp_dir)
        self.remote.transfer(source, target)
        # test if the payload file is in the target directory
        self.assertTrue(os.path.isfile(os.path.join(target, source_file_name)))

    def test_create_directories(self):
        self.remote.create_directories()
        self.assertTrue(os.path.isdir(self.remote.base_path))
        self.assertTrue(os.path.isdir(self.remote.conf_path))
