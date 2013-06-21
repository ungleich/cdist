# -*- coding: utf-8 -*-
#
# 2010-2011 Steven Armstrong (steven-cdist at armstrong.cc)
# 2012-2013 Nico Schottelius (nico-cdist at schottelius.org)
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
from cdist import core
from cdist import config
from cdist.exec import local
from cdist.core import manifest
import cdist.context

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')

object_base_path = op.join(fixtures, 'object')
add_conf_dir = op.join(fixtures, 'conf')
type_base_path = op.join(add_conf_dir, 'type')

class MockContext(object):
    """A context object that has the required attributes"""
    def __init__(self, target_host):
        self.target_host = target_host
        self.local = False

class MockLocal(object):
    def __init__(self, temp_dir, type_path):
        self.temp_dir = temp_dir
        self.object_path = op.join(self.temp_dir, "object")
        self.type_path = type_path

class ExecutionOrderTestCase(test.CdistTestCase):
    def setUp(self):
        # self.orig_environ = os.environ
        # os.environ = os.environ.copy()
        # os.environ['__cdist_out_dir'] = self.out_dir
        # os.environ['__cdist_remote_out_dir'] = self.remote_out_dir
        # self.out_dir = os.path.join(self.temp_dir, "out")
        # self.remote_out_dir = os.path.join(self.temp_dir, "remote")

        self.temp_dir = self.mkdtemp()

        self.context = MockContext(self.target_host)
        self.context.local = MockLocal(self.temp_dir, type_base_path)
        self.config = config.Config(self.context)

        self._init_objects()

    def _init_objects(self):
        """copy base objects to context directory"""
        shutil.copytree(object_base_path, self.context.local.object_path)
        self.objects = list(core.CdistObject.list_objects(self.context.local.object_path, self.context.local.type_path))
        self.object_index = dict((o.name, o) for o in self.objects)

        for cdist_object in self.objects:
            cdist_object.state = core.CdistObject.STATE_UNDEF

    def tearDown(self):
        # os.environ = self.orig_environ
        shutil.rmtree(self.temp_dir)

    def test_objects_changed(self):
        pass
        # self.assert_True(self.config.iterate_once())

class NotTheExecutionOrderTestCase(test.CdistTestCase):
    def test_implicit_dependencies(self):
        self.context.initial_manifest = os.path.join(self.context.local.manifest_path, 'implicit_dependencies')
        self.config.stage_prepare()

        objects = core.CdistObject.list_objects(self.context.local.object_path, self.context.local.type_path)
        dependency_resolver = resolver.DependencyResolver(objects)
        expected_dependencies = [
            dependency_resolver.objects['__package_special/b'],
            dependency_resolver.objects['__package/b'],
            dependency_resolver.objects['__package_special/a']
        ]
        resolved_dependencies = dependency_resolver.dependencies['__package_special/a']
        self.assertEqual(resolved_dependencies, expected_dependencies)
        self.assertTrue(False)

    def test_circular_dependency(self):
        self.context.initial_manifest = os.path.join(self.context.local.manifest_path, 'circular_dependency')
        self.config.stage_prepare()
        # raises CircularDependecyError
        self.config.stage_run()
        self.assertTrue(False)

    def test_recursive_type(self):
        self.context.initial_manifest = os.path.join(self.config.local.manifest_path, 'recursive_type')
        self.config.stage_prepare()
        # raises CircularDependecyError
        self.config.stage_run()
        self.assertTrue(False)
