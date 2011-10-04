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
import tempfile
import unittest

sys.path.insert(0, os.path.abspath(
        os.path.join(os.path.dirname(os.path.realpath(__file__)), '../lib')))

import cdist.config

cdist_exec_path = os.path.abspath(
    os.path.join(os.path.dirname(os.path.realpath(__file__)), "bin/cdist"))


class Install(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.init_manifest = os.path.join(self.temp_dir, "manifest")
        self.config = cdist.config.Config("localhost",
                            initial_manifest=self.init_manifest,
                            exec_path=cdist_exec_path)
        self.config.link_emulator()

### NEW FOR INSTALL ############################################################

    def test_explorer_ran(self):
        """Check that all explorers returned a result"""
        self.config.run_global_explores()
        explorers = self.config.path.list_global_explorers()

        for explorer in explorers:
            output = self.config.path.global_explorer_output_path(explorer)
            self.assertTrue(os.path.isfile(output))

### OLD FROM CONFIG ############################################################
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


