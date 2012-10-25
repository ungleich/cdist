# -*- coding: utf-8 -*-
#
# 2010-2011 Steven Armstrong (steven-cdist at armstrong.cc)
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

import cdist
from cdist import test
from cdist.exec import local
from cdist import core
from cdist.core import manifest
from cdist import resolver
from cdist import config
import cdist.context

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
local_base_path = fixtures


class AutorequireTestCase(test.CdistTestCase):

    def setUp(self):
        self.orig_environ = os.environ
        os.environ = os.environ.copy()
        self.target_host = 'localhost'
        self.temp_dir = self.mkdtemp()
        os.environ['__cdist_out_dir'] = self.temp_dir

        self.context = cdist.context.Context(
            target_host=self.target_host,
            base_path=local_base_path,
            exec_path=test.cdist_exec_path,
            debug=False)
        self.config = config.Config(self.context)

    def tearDown(self):
        os.environ = self.orig_environ
        shutil.rmtree(self.temp_dir)

    def test_implicit_dependencies(self):
        self.context.initial_manifest = os.path.join(self.config.local.manifest_path, 'implicit_dependencies')
        self.config.stage_prepare()

        objects = core.CdistObject.list_objects(self.config.local.object_path, self.config.local.type_path)
        dependency_resolver = resolver.DependencyResolver(objects)
        expected_dependencies = [
            dependency_resolver.objects['__package_special/b'],
            dependency_resolver.objects['__package/b'],
            dependency_resolver.objects['__package_special/a']
        ]
        resolved_dependencies = dependency_resolver.dependencies['__package_special/a']
        self.assertEqual(resolved_dependencies, expected_dependencies)

    def test_circular_dependency(self):
        self.context.initial_manifest = os.path.join(self.config.local.manifest_path, 'circular_dependency')
        self.config.stage_prepare()
        # raises CircularDependecyError
        self.config.stage_run()
