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
import logging

import cdist
from cdist.exec import local
from cdist import core
from cdist.core import manifest

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
local_base_path = fixtures


class ManifestTestCase(unittest.TestCase):

    def mkdtemp(self, **kwargs):
        return tempfile.mkdtemp(prefix='tmp.cdist.test.', **kwargs)

    def mkstemp(self, **kwargs):
        return tempfile.mkstemp(prefix='tmp.cdist.test.', **kwargs)

    def setUp(self):
        self.temp_dir = self.mkdtemp()
        self.target_host = 'localhost'
        out_path = self.temp_dir
        self.local = local.Local(self.target_host, local_base_path, out_path)
        self.local.create_directories()
        self.local.link_emulator(cdist.test.cdist_exec_path)
        self.manifest = manifest.Manifest(self.target_host, self.local)
        self.log = logging.getLogger(self.target_host)

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def test_initial_manifest_environment(self):
        initial_manifest = os.path.join(self.local.manifest_path, "dump_environment")
        self.manifest.run_initial_manifest(initial_manifest)

    def test_type_manifest_environment(self):
        cdist_type = core.Type(self.local.type_path, '__dump_environment')
        cdist_object = core.Object(cdist_type, self.local.object_path, 'whatever')
        self.manifest.run_type_manifest(cdist_object)

    def test_debug_env_setup(self):
        self.log.setLevel(logging.DEBUG)
        manifest = cdist.core.manifest.Manifest(self.target_host, self.local)
        self.assertTrue("__debug" in manifest.env)
