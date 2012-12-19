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
import shutil

from cdist import test
from cdist import core

import cdist
import cdist.context
import cdist.config

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
object_base_path = op.join(fixtures, 'object')
type_base_path = op.join(fixtures, 'type')
add_conf_dir = op.join(fixtures, 'conf')

class ConfigInstallRunTestCase(test.CdistTestCase):

    def setUp(self):

        # Change env for context
        self.orig_environ = os.environ
        os.environ = os.environ.copy()
        self.temp_dir = self.mkdtemp()

        self.out_dir = os.path.join(self.temp_dir, "out")
        self.remote_out_dir = os.path.join(self.temp_dir, "remote")

        os.environ['__cdist_out_dir'] = self.out_dir
        os.environ['__cdist_remote_out_dir'] = self.remote_out_dir

        self.context = cdist.context.Context(
            target_host=self.target_host,
            remote_copy=self.remote_copy,
            remote_exec=self.remote_exec,
            exec_path=test.cdist_exec_path,
            debug=True)

        self.context.local.object_path = object_base_path
        self.context.local.type_path = type_base_path

        self.config = cdist.config.Config(self.context)

        self.objects = list(core.CdistObject.list_objects(object_base_path, type_base_path))
        self.object_index = dict((o.name, o) for o in self.objects)
        self.object_names = [o.name for o in self.objects]

    def tearDown(self):
        for o in self.objects:
            o.requirements = []
            o.state = ""

        os.environ = self.orig_environ
        shutil.rmtree(self.temp_dir)

    def test_dependency_resolution(self):
        first   = self.object_index['__first/man']
        second  = self.object_index['__second/on-the']
        third   = self.object_index['__third/moon']

        first.requirements = [second.name]
        second.requirements = [third.name]

        # First run: 
        # solves first and maybe second (depending on the order in the set)
        self.config.stage_run_iterate()
        self.assertTrue(third.state == third.STATE_DONE)

        self.config.stage_run_iterate()
        self.assertTrue(second.state == second.STATE_DONE)


        try:
            self.config.stage_run_iterate()
        except cdist.Error:
            # Allow failing, because the third run may or may not be unecessary already,
            # depending on the order of the objects
            pass
        self.assertTrue(first.state == first.STATE_DONE)

    def test_unresolvable_requirements(self):
        """Ensure an exception is thrown for unresolvable depedencies"""

        # Create to objects depending on each other - no solution possible
        first   = self.object_index['__first/man']
        second  = self.object_index['__second/on-the']

        first.requirements = [second.name]
        second.requirements = [first.name]

        # First round solves __third/moon
        self.config.stage_run_iterate()

        # Second round detects it cannot solve the rest
        with self.assertRaises(cdist.Error):
            self.config.stage_run_iterate()
