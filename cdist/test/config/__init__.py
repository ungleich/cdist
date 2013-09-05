# -*- coding: utf-8 -*-
#
# 2010-2017 Steven Armstrong (steven-cdist at armstrong.cc)
# 2012-2015 Nico Schottelius (nico-cdist at schottelius.org)
# 2014      Daniel Heule     (hda at sfs.biz)
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
import tempfile

from cdist import test
from cdist import core

import cdist
import cdist.config
import cdist.core.cdist_type
import cdist.core.cdist_object

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
type_base_path = op.join(fixtures, 'type')
add_conf_dir = op.join(fixtures, 'conf')

expected_object_names = sorted([
    '__first/man',
    '__second/on-the',
    '__third/moon'])


class CdistObjectErrorContext(object):
    def __init__(self, original_error):
        self.original_error = original_error

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, tb):
        if exc_type is not None:
            if exc_value.original_error:
                raise exc_value.original_error


class ConfigRunTestCase(test.CdistTestCase):

    def setUp(self):

        # Change env for context
        self.orig_environ = os.environ
        os.environ = os.environ.copy()
        self.temp_dir = self.mkdtemp()

        self.local_dir = os.path.join(self.temp_dir, "local")
        self.hostdir = cdist.str_hash(self.target_host[0])
        self.host_base_path = os.path.join(self.local_dir, self.hostdir)
        os.makedirs(self.host_base_path)
        self.local = cdist.exec.local.Local(
            target_host=self.target_host,
            target_host_tags=self.target_host_tags,
            base_root_path=self.host_base_path,
            host_dir_name=self.hostdir)

        # Setup test objects
        self.object_base_path = op.join(self.temp_dir, 'object')

        self.objects = []
        for cdist_object_name in expected_object_names:
            cdist_type, cdist_object_id = cdist_object_name.split("/", 1)
            cdist_object = core.CdistObject(core.CdistType(type_base_path,
                                                           cdist_type),
                                            self.object_base_path,
                                            self.local.object_marker_name,
                                            cdist_object_id)
            cdist_object.create()
            self.objects.append(cdist_object)

        self.object_index = dict((o.name, o) for o in self.objects)
        self.object_names = [o.name for o in self.objects]

        self.remote_dir = os.path.join(self.temp_dir, "remote")
        os.mkdir(self.remote_dir)
        self.remote = cdist.exec.remote.Remote(
            target_host=self.target_host,
            remote_copy=self.remote_copy,
            remote_exec=self.remote_exec,
            base_path=self.remote_dir,
            stdout_base_path=self.local.stdout_base_path,
            stderr_base_path=self.local.stderr_base_path)

        self.local.object_path = self.object_base_path
        self.local.type_path = type_base_path

        self.config = cdist.config.Config(self.local, self.remote)

    def tearDown(self):
        for o in self.objects:
            o.requirements = []
            o.state = ""

        os.environ = self.orig_environ
        shutil.rmtree(self.temp_dir)

    def assertRaisesCdistObjectError(self, original_error, callable_obj):
        """
        Test if a raised CdistObjectError was caused by the given
        original_error.
        """
        with self.assertRaises(original_error):
            try:
                callable_obj()
            except cdist.CdistObjectError as e:
                if e.original_error:
                    raise e.original_error
                else:
                    raise

    def test_dependency_resolution(self):
        first = self.object_index['__first/man']
        second = self.object_index['__second/on-the']
        third = self.object_index['__third/moon']

        first.requirements = [second.name]
        second.requirements = [third.name]

        # First run:
        # solves first and maybe second (depending on the order in the set)
        self.config.iterate_once()
        self.assertTrue(third.state == third.STATE_DONE)

        self.config.iterate_once()
        self.assertTrue(second.state == second.STATE_DONE)

        try:
            self.config.iterate_once()
        except cdist.Error:
            # Allow failing, because the third run may or may not be
            # unecessary already,
            # depending on the order of the objects
            pass
        self.assertTrue(first.state == first.STATE_DONE)

    def test_unresolvable_requirements(self):
        """Ensure an exception is thrown for unresolvable depedencies"""

        # Create to objects depending on each other - no solution possible
        first = self.object_index['__first/man']
        second = self.object_index['__second/on-the']

        first.requirements = [second.name]
        second.requirements = [first.name]

        self.assertRaisesCdistObjectError(
            cdist.UnresolvableRequirementsError,
            self.config.iterate_until_finished)

    def test_missing_requirements(self):
        """Throw an error if requiring something non-existing"""
        first = self.object_index['__first/man']
        first.requirements = ['__first/not/exist']
        self.assertRaisesCdistObjectError(
            cdist.UnresolvableRequirementsError,
            self.config.iterate_until_finished)

    def test_requirement_broken_type(self):
        """Unknown type should be detected in the resolving process"""
        first = self.object_index['__first/man']
        first.requirements = ['__nosuchtype/not/exist']
        self.assertRaisesCdistObjectError(
            cdist.core.cdist_type.NoSuchTypeError,
            self.config.iterate_until_finished)

    def test_requirement_singleton_where_no_singleton(self):
        """Missing object id should be detected in the resolving process"""
        first = self.object_index['__first/man']
        first.requirements = ['__first']
        self.assertRaisesCdistObjectError(
            cdist.core.cdist_object.MissingObjectIdError,
            self.config.iterate_until_finished)

    def test_dryrun(self):
        """Test if the dryrun option is working like expected"""
        drylocal = cdist.exec.local.Local(
            target_host=self.target_host,
            target_host_tags=self.target_host_tags,
            base_root_path=self.host_base_path,
            host_dir_name=self.hostdir,
            # exec_path can not derivated from sys.argv in case of unittest
            exec_path=os.path.abspath(os.path.join(
                my_dir, '../../../scripts/cdist')),
            initial_manifest=os.path.join(fixtures,
                                          'manifest/dryrun_manifest'),
            add_conf_dirs=[fixtures])

        dryrun = cdist.config.Config(drylocal, self.remote, dry_run=True)
        dryrun.run()
        # if we are here, dryrun works like expected

    def test_desp_resolver(self):
        """Test to show dependency resolver warning message."""
        local = cdist.exec.local.Local(
            target_host=self.target_host,
            target_host_tags=self.target_host_tags,
            base_root_path=self.host_base_path,
            host_dir_name=self.hostdir,
            exec_path=os.path.abspath(os.path.join(
                my_dir, '../../../scripts/cdist')),
            initial_manifest=os.path.join(
                fixtures, 'manifest/init-deps-resolver'),
            add_conf_dirs=[fixtures])

        # dry_run is ok for dependency testing
        config = cdist.config.Config(local, self.remote, dry_run=True)
        config.run()


# Currently the resolving code will simply detect that this object does
# not exist. It should probably check if the type is a singleton as well
# - but maybe only in the emulator - to be discussed.
#
#    def test_requirement_no_singleton_where_singleton(self):
#        """Missing object id should be detected in the resolving process"""
#        first = self.object_index['__first/man']
#        first.requirements = ['__singleton_test/foo']
#        with self.assertRaises(cdist.core.?????):
#            self.config.iterate_until_finished()

if __name__ == "__main__":
    import unittest

    unittest.main()
