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

import io
import sys
import unittest

import cdist
import cdist.banner

class Banner(unittest.TestCase):
    def setUp(self):
        self.banner = cdist.BANNER + "\n"

    def test_banner_output(self):
        """Check that printed banner equals saved banner"""
        output = io.StringIO()

        sys.stdout = output

        cdist.banner.banner(None)
        
        self.assertEqual(output.getvalue(), self.banner)
