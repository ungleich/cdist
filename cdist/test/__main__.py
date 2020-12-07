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

import importlib
import os
import sys
import unittest

base_dir = os.path.dirname(os.path.realpath(__file__))

test_modules = []
for possible_test in os.listdir(base_dir):
    filename = "__init__.py"
    mod_path = os.path.join(base_dir, possible_test, filename)

    if os.path.isfile(mod_path):
        test_modules.append(possible_test)

suites = []
for test_module in test_modules:
    module_spec = importlib.util.find_spec("cdist.test.{}".format(test_module))
    module = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(module)

    suite = unittest.defaultTestLoader.loadTestsFromModule(module)
    # print("Got suite: " + suite.__str__())
    suites.append(suite)

all_suites = unittest.TestSuite(suites)
rv = unittest.TextTestRunner(verbosity=2).run(all_suites).wasSuccessful()
sys.exit(not rv)
