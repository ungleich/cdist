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
import unittest

sys.path.insert(0, os.path.abspath(
        os.path.join(os.path.dirname(os.path.realpath(__file__)), 'lib')))

import cdist
import cdist.config
import cdist.exec

class Exec(unittest.TestCase):
    def test_local_success(self):
        try:
            cdist.exec.run_or_fail(["/bin/true"])
        except cdist.Error:
            failed = True
        else:
            failed = False

        self.assertFalse(failed)

    def test_local_fail(self):
        try:
            cdist.exec.run_or_fail(["/bin/false"])
        except cdist.Error:
            failed = True
        else:
            failed = False

        self.assertTrue(failed)
            


if __name__ == '__main__':
    unittest.main()
