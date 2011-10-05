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
import shutil
import sys
import tempfile
import unittest

import cdist.path
import cdist.test

class Path(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.init_manifest = os.path.join(self.temp_dir, "manifest")
        self.path = cdist.path.Path("localhost", "root", "ssh root@localhost",
            initial_manifest=self.init_manifest,
            base_dir=self.temp_dir)

        os.mkdir(self.path.conf_dir)
        os.mkdir(self.path.type_base_dir)

        self.install_type_name = "__install_test"
        self.config_type_name = "__config_test"

        # Create install type
        self.install_type = os.path.join(self.path.type_base_dir, self.install_type_name)
        os.mkdir(self.install_type)
        open(os.path.join(self.install_type, "install"), "w").close()

        # Create config type
        self.config_type = os.path.join(self.path.type_base_dir, self.config_type_name)
        os.mkdir(self.config_type)

    def tearDown(self):
        self.path.cleanup()
        shutil.rmtree(self.temp_dir)

    def test_type_detection(self):
        """Check that a type is identified as install or configuration correctly"""
        
        self.assertTrue(self.path.is_install_type(self.install_type))
        self.assertFalse(self.path.is_install_type(self.config_type))

    def test_manifest_uses_install_types_only(self):
        """Check that objects created from manifest are only of install type"""
        manifest_fd = open(self.init_manifest, "w")
        manifest_fd.writelines(["#!/bin/sh\n",
            self.install_type_name + "testid\n",
            self.config_type_name + "testid\n",
            ])
        manifest_fd.close()

        self.install.run_initial_manifest()

        # FIXME: check that only __partition_msdos objects are created!

        self.assertFalse(failed)
