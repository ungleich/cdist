#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2011 Nico Schottelius (nico-cdist at schottelius.org)
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
import sys
import shutil
import subprocess
import tempfile
import unittest

sys.path.insert(0, os.path.abspath(
        os.path.join(os.path.dirname(os.path.realpath(__file__)), 'lib')))

cdist_exec_path = os.path.abspath(
    os.path.join(os.path.dirname(os.path.realpath(__file__)), "bin/cdist"))

cdist_commands=["banner", "config", "install"]

import cdist
import cdist.config
import cdist.exec

class Exec(unittest.TestCase):
    def setUp(self):
        """Create shell code and co."""

        self.temp_dir = tempfile.mkdtemp()
        self.shell_false = os.path.join(self.temp_dir, "shell_false")
        self.shell_true  = os.path.join(self.temp_dir, "shell_true")

        true_fd = open(self.shell_true, "w")
        true_fd.writelines(["#!/bin/sh\n", "/bin/true"])
        true_fd.close()
        
        false_fd = open(self.shell_false, "w")
        false_fd.writelines(["#!/bin/sh\n", "/bin/false"])
        false_fd.close()

    def tearDown(self):
        shutil.rmtree(self.temp_dir)
        
    def test_local_success_shell(self):
        try:
            cdist.exec.shell_run_or_debug_fail(self.shell_true, [self.shell_true])
        except cdist.Error:
            failed = True
        else:
            failed = False

        self.assertFalse(failed)

    def test_local_fail_shell(self):
        self.assertRaises(cdist.Error, cdist.exec.shell_run_or_debug_fail,
            self.shell_false, [self.shell_false])

    def test_local_success(self):
        try:
            cdist.exec.run_or_fail(["/bin/true"])
        except cdist.Error:
            failed = True
        else:
            failed = False

        self.assertFalse(failed)

    def test_local_fail(self):
        self.assertRaises(cdist.Error, cdist.exec.run_or_fail, ["/bin/false"])

class Config(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.init_manifest = os.path.join(self.temp_dir, "manifest")
        self.config = cdist.config.Config("localhost",
                            initial_manifest=self.init_manifest,
                            exec_path=cdist_exec_path)
        self.config.link_emulator()

    def test_initial_manifest_different_parameter(self):
        manifest_fd = open(self.init_manifest, "w")
        manifest_fd.writelines(["#!/bin/sh\n",
            "__file " + self.temp_dir + " --mode 0700\n",
            "__file " + self.temp_dir + " --mode 0600\n",
            ])
        manifest_fd.close()

        self.assertRaises(cdist.Error, self.config.run_initial_manifest)

    def test_initial_manifest_parameter_added(self):
        manifest_fd = open(self.init_manifest, "w")
        manifest_fd.writelines(["#!/bin/sh\n",
            "__file " + self.temp_dir + '\n',
            "__file " + self.temp_dir + " --mode 0600\n",
            ])
        manifest_fd.close()

        self.assertRaises(cdist.Error, self.config.run_initial_manifest)

    def test_initial_manifest_parameter_removed(self):
        manifest_fd = open(self.init_manifest, "w")
        manifest_fd.writelines(["#!/bin/sh\n",
            "__file " + self.temp_dir + " --mode 0600\n",
            "__file " + self.temp_dir + "\n",
            ])
        manifest_fd.close()

        self.assertRaises(cdist.Error, self.config.run_initial_manifest)

    def test_initial_manifest_non_existent_command(self):
        manifest_fd = open(self.init_manifest, "w")
        manifest_fd.writelines(["#!/bin/sh\n",
            "thereisdefinitelynosuchcommend"])
        manifest_fd.close()

        self.assertRaises(cdist.Error, self.config.run_initial_manifest)

    def test_initial_manifest_parameter_twice(self):
        manifest_fd = open(self.init_manifest, "w")
        manifest_fd.writelines(["#!/bin/sh\n",
            "__file " + self.temp_dir + " --mode 0600\n",
            "__file " + self.temp_dir + " --mode 0600\n",
            ])
        manifest_fd.close()

        try:
            self.config.run_initial_manifest()
        except cdist.Error:
            failed = True
        else:
            failed = False

        self.assertFalse(failed)


class UI(unittest.TestCase):
    def test_banner(self):
        self.assertEqual(subprocess.call([cdist_exec_path, "banner"]), 0)

    def test_help(self):
        for cmd in cdist_commands:
            self.assertEqual(subprocess.call([cdist_exec_path, cmd, "-h"]), 0)

    # FIXME: mockup needed
    def test_config_localhost(self):
        for cmd in cdist_commands:
            self.assertEqual(subprocess.call([cdist_exec_path, "config", "localhost"]), 0)


def almost_all_tests():
    suite = unittest.TestSuite([
        unittest.TestLoader().loadTestsFromTestCase(Config),
        unittest.TestLoader().loadTestsFromTestCase(Exec)])

    return suite

def all_tests():
    suite = unittest.defaultTestLoader
    return suite

if __name__ == '__main__':
    result = unittest.TestResult()
    # only run some tests, when giving -a -> stuff that usually breaks
    if len(sys.argv) >= 2:
        if sys.argv[1] == "-a":
            suite = all_tests();
        else:
            sys.exit(1)
    else:
        suite = almost_all_tests();

    # suite.run(result)
    # unittest.main()
    # unittest.TextTestRunner().run(suite)

