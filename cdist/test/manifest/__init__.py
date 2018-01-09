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
import logging
import io
import sys

import cdist
from cdist import test
from cdist.exec import local
from cdist import core
from cdist.core import manifest

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
conf_dir = op.join(fixtures, 'conf')


class ManifestTestCase(test.CdistTestCase):

    def setUp(self):
        self.orig_environ = os.environ
        os.environ = os.environ.copy()
        self.temp_dir = self.mkdtemp()

        out_path = self.temp_dir
        hostdir = cdist.str_hash(self.target_host[0])
        base_root_path = os.path.join(out_path, hostdir)
        self.local = local.Local(
            target_host=self.target_host,
            target_host_tags=self.target_host_tags,
            base_root_path=base_root_path,
            host_dir_name=hostdir,
            exec_path=cdist.test.cdist_exec_path,
            add_conf_dirs=[conf_dir])
        self.local.create_files_dirs()

        self.manifest = manifest.Manifest(self.target_host, self.local)
        self.log = logging.getLogger(self.target_host[0])

    def tearDown(self):
        os.environ = self.orig_environ
        shutil.rmtree(self.temp_dir)

    def test_initial_manifest_environment(self):
        initial_manifest = os.path.join(self.local.manifest_path,
                                        "dump_environment")
        handle, output_file = self.mkstemp(dir=self.temp_dir)
        os.close(handle)
        os.environ['__cdist_test_out'] = output_file
        old_loglevel = logging.root.getEffectiveLevel()
        self.log.setLevel(logging.VERBOSE)
        manifest = cdist.core.manifest.Manifest(self.target_host, self.local)
        manifest.run_initial_manifest(initial_manifest)

        with open(output_file, 'r') as fd:
            output_string = fd.read()
        output_dict = {}
        for line in output_string.split('\n'):
            if line:
                key, value = line.split(': ')
                output_dict[key] = value
        self.assertTrue(output_dict['PATH'].startswith(self.local.bin_path))
        self.assertEqual(output_dict['__target_host'],
                         self.local.target_host[0])
        self.assertEqual(output_dict['__target_hostname'],
                         self.local.target_host[1])
        self.assertEqual(output_dict['__target_fqdn'],
                         self.local.target_host[2])
        self.assertEqual(output_dict['__global'], self.local.base_path)
        self.assertEqual(output_dict['__cdist_type_base_path'],
                         self.local.type_path)
        self.assertEqual(output_dict['__manifest'], self.local.manifest_path)
        self.assertEqual(output_dict['__files'], self.local.files_path)
        self.assertEqual(output_dict['__target_host_tags'],
                         self.local.target_host_tags)
        self.assertEqual(output_dict['__cdist_log_level'],
                         str(logging.VERBOSE))
        self.assertEqual(output_dict['__cdist_log_level_name'], 'VERBOSE')
        self.log.setLevel(old_loglevel)

    def test_type_manifest_environment(self):
        cdist_type = core.CdistType(self.local.type_path, '__dump_environment')
        cdist_object = core.CdistObject(cdist_type, self.local.object_path,
                                        self.local.object_marker_name,
                                        'whatever')
        cdist_object.create()
        handle, output_file = self.mkstemp(dir=self.temp_dir)
        os.close(handle)
        os.environ['__cdist_test_out'] = output_file
        old_loglevel = self.log.getEffectiveLevel()
        self.log.setLevel(logging.VERBOSE)
        manifest = cdist.core.manifest.Manifest(self.target_host, self.local)
        manifest.run_type_manifest(cdist_object)

        with open(output_file, 'r') as fd:
            output_string = fd.read()
        output_dict = {}
        for line in output_string.split('\n'):
            if line:
                key, value = line.split(': ')
                output_dict[key] = value
        self.assertTrue(output_dict['PATH'].startswith(self.local.bin_path))
        self.assertEqual(output_dict['__target_host'],
                         self.local.target_host[0])
        self.assertEqual(output_dict['__target_hostname'],
                         self.local.target_host[1])
        self.assertEqual(output_dict['__target_fqdn'],
                         self.local.target_host[2])
        self.assertEqual(output_dict['__global'], self.local.base_path)
        self.assertEqual(output_dict['__cdist_type_base_path'],
                         self.local.type_path)
        self.assertEqual(output_dict['__type'], cdist_type.absolute_path)
        self.assertEqual(output_dict['__object'], cdist_object.absolute_path)
        self.assertEqual(output_dict['__object_id'], cdist_object.object_id)
        self.assertEqual(output_dict['__object_name'], cdist_object.name)
        self.assertEqual(output_dict['__files'], self.local.files_path)
        self.assertEqual(output_dict['__target_host_tags'],
                         self.local.target_host_tags)
        self.assertEqual(output_dict['__cdist_log_level'],
                         str(logging.VERBOSE))
        self.assertEqual(output_dict['__cdist_log_level_name'], 'VERBOSE')
        self.log.setLevel(old_loglevel)

    def test_loglevel_env_setup(self):
        current_level = self.log.getEffectiveLevel()
        self.log.setLevel(logging.DEBUG)
        manifest = cdist.core.manifest.Manifest(self.target_host, self.local)
        self.assertTrue("__cdist_log_level" in manifest.env)
        self.assertTrue("__cdist_log_level_name" in manifest.env)
        self.assertEqual(manifest.env["__cdist_log_level"],
                         str(logging.DEBUG))
        self.assertEqual(manifest.env["__cdist_log_level_name"], 'DEBUG')
        self.log.setLevel(current_level)


if __name__ == '__main__':
    import unittest
    unittest.main()
