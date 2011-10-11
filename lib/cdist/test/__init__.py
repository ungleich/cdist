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
import subprocess
import unittest

cdist_commands=["banner", "config", "install"]

cdist_base_path = os.path.abspath(
    os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../"))

cdist_exec_path = os.path.join(cdist_base_path, "bin/cdist")

#class UI(unittest.TestCase):
#    def test_banner(self):
#        self.assertEqual(subprocess.call([cdist_exec_path, "banner"]), 0)
#
#    def test_help(self):
#        for cmd in cdist_commands:
#            self.assertEqual(subprocess.call([cdist_exec_path, cmd, "-h"]), 0)
#
#    # FIXME: mockup needed
#    def test_config_localhost(self):
#        for cmd in cdist_commands:
#            self.assertEqual(subprocess.call([cdist_exec_path, "config", "localhost"]), 0)
