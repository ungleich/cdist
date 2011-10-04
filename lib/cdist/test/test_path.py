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

import cdist.path
import cdist.test

class Path(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.init_manifest = os.path.join(self.temp_dir, "manifest")
        self.path = cdist.config.Path("localhost", "root",
            "ssh root@localhost",
            initial_manifest=self.init_manifest,
            base_dir=self.temp_dir)

    def tearDown(self):
        self.path.cleanup()

    def test_type_detection(self):
        """Check that a type is identified as install or configuration correctly"""

        # Create install type
        install_type = os.path.join(
        os.mkdir(
        # Create non-install type

        self.config.run_global_explores()
        explorers = self.config.path.list_global_explorers()

        for explorer in explorers:
            output = self.config.path.global_explorer_output_path(explorer)
            self.assertTrue(os.path.isfile(output))

    def test_manifest_uses_install_types_only(self):
        """Check that objects created from manifest are only of install type"""
        manifest_fd = open(self.init_manifest, "w")
        manifest_fd.writelines(["#!/bin/sh\n",
            "__file " + self.temp_dir + " --mode 0700\n",
            "__partition_msdos /dev/null --type 82\n",
            ])
        manifest_fd.close()

        self.config.run_initial_manifest()

        # FIXME: check that only __partition_msdos objects are created!

        self.assertFalse(failed)
