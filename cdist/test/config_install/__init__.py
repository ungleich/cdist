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

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
object_base_path = op.join(fixtures, 'object')
type_base_path = op.join(fixtures, 'type')
add_conf_dir = op.join(fixtures, 'conf')

class ConfigInstallRunTestCase(test.CdistTestCase):

    def setUp(self):

        self.context = cdist.context.Context(
            target_host=self.target_host,
            remote_copy=self.remote_copy,
            remote_exec=self.remote_exec,
            initial_manifest=args.manifest,
            add_conf_dirs=add_conf_dir,
            exec_path=test.cdist_exec_path,
            debug=False)

        self.config = config.Config(self.context)

    def setUp(self):
        self.objects = list(core.CdistObject.list_objects(object_base_path, type_base_path))
        self.object_index = dict((o.name, o) for o in self.objects)
        self.object_names = [o.name for o in self.objects]

        print(self.objects)

        self.cdist_type = core.CdistType(type_base_path, '__third')
        self.cdist_object = core.CdistObject(self.cdist_type, object_base_path, 'moon') 

    def tearDown(self):
        for o in self.objects:
            o.requirements = []

    def test_dependency_resolution(self):
        first   = self.object_index['__first/man']
        second  = self.object_index['__second/on-the']
        third   = self.object_index['__third/moon']

        first.requirements = [second.name]
        second.requirements = [third.name]

        self.config.stage_run_prepare()

        # First run: 
        # solves first and maybe second (depending on the order in the set)
        self.config.stage_run_iterate()

        # FIXME :-)
        self.assertTrue(False)
#        self.assertEqual(
#            self.dependency_resolver.dependencies['__first/man'],
#            [third_moon, second_on_the, first_man]
#        )

    def test_requirement_not_found(self):
        first_man = self.object_index['__first/man']
        first_man.requirements = ['__does/not/exist']
        with self.assertRaises(core.cdist_object.RequirementNotFoundError):
            first_man.find_requirements_by_name(first_man.requirements)
