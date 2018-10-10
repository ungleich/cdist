# -*- coding: utf-8 -*-
#
# 2010-2011 Steven Armstrong (steven-cdist at armstrong.cc)
# 2012 Nico Schottelius (nico-cdist at schottelius.org)
# 2016 Darko Poljak (darko.poljak at gmail.com)
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
import time
import datetime
import argparse

import cdist
import cdist.configuration as cc
from cdist import test
from cdist.exec import local

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
conf_dir = op.join(fixtures, "conf")

bin_true = "true"
bin_false = "false"


class LocalTestCase(test.CdistTestCase):

    def setUp(self):

        target_host = (
            'localhost',
            'localhost',
            'localhost',
        )
        self.temp_dir = self.mkdtemp()
        self.out_parent_path = self.temp_dir
        self.hostdir = cdist.str_hash(target_host[0])
        self.host_base_path = op.join(self.out_parent_path, self.hostdir)
        self.out_path = op.join(self.host_base_path, "data")

        self.local = local.Local(
            target_host=target_host,
            target_host_tags=None,
            base_root_path=self.host_base_path,
            host_dir_name=self.hostdir,
            exec_path=test.cdist_exec_path
        )

        self.home_dir = os.path.join(os.environ['HOME'], ".cdist")

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    # test api

    def test_cache_path(self):
        self.assertEqual(self.local.cache_path,
                         os.path.join(self.home_dir, "cache"))

    def test_conf_path(self):
        self.assertEqual(self.local.conf_path,
                         os.path.join(self.out_path, "conf"))

    def test_out_path(self):
        self.assertEqual(self.local.base_path, self.out_path)

    def test_bin_path(self):
        self.assertEqual(self.local.bin_path,
                         os.path.join(self.out_path, "bin"))

    def test_global_explorer_out_path(self):
        self.assertEqual(self.local.global_explorer_out_path,
                         os.path.join(self.out_path, "explorer"))

    def test_object_path(self):
        self.assertEqual(self.local.object_path,
                         os.path.join(self.out_path, "object"))

    # /test api

    # test internal implementation

    def test_global_explorer_path(self):
        self.assertEqual(self.local.global_explorer_path,
                         os.path.join(self.out_path, "conf", "explorer"))

    def test_manifest_path(self):
        self.assertEqual(self.local.manifest_path,
                         os.path.join(self.out_path, "conf", "manifest"))

    def test_type_path(self):
        self.assertEqual(self.local.type_path,
                         os.path.join(self.out_path, "conf", "type"))

    def test_dist_conf_dir_linking(self):
        """Ensure that links are correctly created for types included
           in distribution"""

        test_type = "__file"

        link_test_local = local.Local(
            target_host=(
                'localhost',
                'localhost',
                'localhost',
            ),
            target_host_tags=None,
            base_root_path=self.host_base_path,
            host_dir_name=self.hostdir,
            exec_path=test.cdist_exec_path,
        )

        link_test_local._create_conf_path_and_link_conf_dirs()

        our_type_dir = os.path.join(link_test_local.type_path, test_type)

        self.assertTrue(os.path.isdir(our_type_dir))

    def test_added_conf_dir_linking(self):
        """Ensure that links are correctly created for types in added conf
           directories"""

        test_type = "__cdist_test_type"

        link_test_local = local.Local(
            target_host=(
                'localhost',
                'localhost',
                'localhost',
            ),
            target_host_tags=None,
            base_root_path=self.host_base_path,
            host_dir_name=self.hostdir,
            exec_path=test.cdist_exec_path,
            add_conf_dirs=[conf_dir]
        )

        link_test_local._create_conf_path_and_link_conf_dirs()

        our_type_dir = os.path.join(link_test_local.type_path, test_type)

        self.assertTrue(os.path.isdir(our_type_dir))

    def test_conf_dir_from_path_linking(self):
        """Ensure that links are correctly created for types in conf
           directories which are defined in CDIST_PATH"""

        test_type = "__cdist_test_type"

        os.environ['CDIST_PATH'] = conf_dir

        # bypass singleton from other tests if any
        cc.Configuration.instance = None

        configuration = cc.Configuration(argparse.Namespace(),
                                         env=os.environ)

        link_test_local = local.Local(
            target_host=(
                'localhost',
                'localhost',
                'localhost',
            ),
            target_host_tags=None,
            base_root_path=self.host_base_path,
            host_dir_name=self.hostdir,
            exec_path=test.cdist_exec_path,
            configuration=configuration.get_config(section='GLOBAL')
        )

        link_test_local._create_conf_path_and_link_conf_dirs()

        our_type_dir = os.path.join(link_test_local.type_path, test_type)

        self.assertTrue(os.path.isdir(our_type_dir))

    # other tests

    def test_run_success(self):
        self.local.create_files_dirs()
        self.local.run([bin_true])

    def test_run_fail(self):
        self.local.create_files_dirs()
        self.assertRaises(cdist.Error, self.local.run, [bin_false])

    def test_run_script_success(self):
        self.local.create_files_dirs()
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", bin_true])
        self.local.run_script(script)

    def test_run_script_fail(self):
        self.local.create_files_dirs()
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", bin_false])
        self.assertRaises(cdist.Error, self.local.run_script, script)

    def test_run_script_get_output(self):
        self.local.create_files_dirs()
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", "echo foobar"])
        self.assertEqual(self.local.run_script(script, return_output=True),
                         "foobar\n")

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
        self.assertTrue(os.path.isdir(self.local.base_path))
        self.assertTrue(os.path.isdir(self.local.bin_path))
        self.assertTrue(os.path.isdir(self.local.conf_path))

    def test_cache_subpath(self):
        start_time = time.time()
        dt = datetime.datetime.fromtimestamp(start_time)
        pid = str(os.getpid())
        cases = [
            ['', self.local.hostdir, ],
            ['/', self.local.hostdir, ],
            ['//', self.local.hostdir, ],
            ['/%%h', '%h', ],
            ['%%h', '%h', ],
            ['%P', pid, ],
            ['x%P', 'x' + pid, ],
            ['%h', self.hostdir, ],
            ['%h/%Y-%m-%d/%H%M%S%f%P',
             dt.strftime(self.hostdir + '/%Y-%m-%d/%H%M%S%f') + pid, ],
            ['/%h/%Y-%m-%d/%H%M%S%f%P',
             dt.strftime(self.hostdir + '/%Y-%m-%d/%H%M%S%f') + pid, ],
            ['%Y-%m-%d/%H%M%S%f%P/%h',
             dt.strftime('%Y-%m-%d/%H%M%S%f' + pid + os.sep + self.hostdir), ],
            ['///%Y-%m-%d/%H%M%S%f%P/%h',
             dt.strftime('%Y-%m-%d/%H%M%S%f' + pid + os.sep + self.hostdir), ],
            ['%h/%Y-%m-%d/%H%M%S-%P',
             dt.strftime(self.hostdir + '/%Y-%m-%d/%H%M%S-') + pid, ],
            ['%Y-%m-%d/%H%M%S-%P/%h',
             dt.strftime('%Y-%m-%d/%H%M%S-') + pid + os.sep + self.hostdir, ],
            ['%N', self.local.target_host[0], ],
        ]
        for x in cases:
            x.append(self.local._cache_subpath(start_time, x[0]))
        # for fmt, expected, actual in cases:
        #     print('\'{}\' \'{}\' \'{}\''.format(fmt, expected, actual))
        for fmt, expected, actual in cases:
            self.assertEqual(expected, actual)


if __name__ == "__main__":
    import unittest

    unittest.main()
