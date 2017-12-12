# -*- coding: utf-8 -*-
#
# 2011-2013 Steven Armstrong (steven-cdist at armstrong.cc)
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
from cdist import core
from cdist import test
from cdist.exec import local
from cdist.exec import remote
from cdist.core import code
from cdist.core import manifest

import os.path as op
my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
conf_dir = op.join(fixtures, 'conf')


class CaptureOutputTestCase(test.CdistTestCase):

    def setUp(self):
        # logging.root.setLevel(logging.TRACE)
        self.temp_dir = self.mkdtemp()

        self.local_dir = os.path.join(self.temp_dir, "local")
        self.hostdir = cdist.str_hash(self.target_host[0])
        self.host_base_path = os.path.join(self.local_dir, self.hostdir)
        os.makedirs(self.host_base_path)
        self.local = local.Local(
            target_host=self.target_host,
            target_host_tags=None,
            base_root_path=self.host_base_path,
            host_dir_name=self.hostdir,
            exec_path=cdist.test.cdist_exec_path,
            add_conf_dirs=[conf_dir])
        self.local.create_files_dirs()

        self.remote_dir = self.mkdtemp()
        remote_exec = self.remote_exec
        remote_copy = self.remote_copy
        self.remote = remote.Remote(
            target_host=self.target_host,
            remote_exec=remote_exec,
            remote_copy=remote_copy,
            base_path=self.remote_dir,
            stdout_base_path=self.local.stdout_base_path,
            stderr_base_path=self.local.stderr_base_path)
        self.remote.create_files_dirs()

        self.code = code.Code(self.target_host, self.local, self.remote)

        self.manifest = manifest.Manifest(self.target_host, self.local)

        self.cdist_type = core.CdistType(self.local.type_path,
                                         '__write_to_stdout_and_stderr')
        self.cdist_object = core.CdistObject(self.cdist_type,
                                             self.local.object_path,
                                             self.local.object_marker_name,
                                             '')
        self.cdist_object.create()
        self.output_dirs = {
            'object': {
                'stdout': os.path.join(self.cdist_object.absolute_path,
                                       'stdout'),
                'stderr': os.path.join(self.cdist_object.absolute_path,
                                       'stderr'),
            },
            'init': {
                'stdout': os.path.join(self.local.base_path, 'stdout'),
                'stderr': os.path.join(self.local.base_path, 'stderr'),
            },
        }

    def tearDown(self):
        shutil.rmtree(self.local_dir)
        shutil.rmtree(self.remote_dir)
        shutil.rmtree(self.temp_dir)

    def _test_output(self, which, target, streams=('stdout', 'stderr')):
        for stream in streams:
            _should = '{0}: {1}\n'.format(which, stream)
            stream_path = os.path.join(self.output_dirs[target][stream], which)
            with open(stream_path, 'r') as fd:
                _is = fd.read()
            self.assertEqual(_should, _is)

    def test_capture_code_output(self):
        self.cdist_object.code_local = self.code.run_gencode_local(
            self.cdist_object)
        self._test_output('gencode-local', 'object', ('stderr',))

        self.code.run_code_local(self.cdist_object)
        self._test_output('code-local', 'object')

        self.cdist_object.code_remote = self.code.run_gencode_remote(
            self.cdist_object)
        self._test_output('gencode-remote', 'object', ('stderr',))

        self.code.transfer_code_remote(self.cdist_object)
        self.code.run_code_remote(self.cdist_object)
        self._test_output('code-remote', 'object')

    def test_capture_manifest_output(self):
        self.manifest.run_type_manifest(self.cdist_object)
        self._test_output('manifest', 'object')

    def test_capture_init_manifest_output(self):
        initial_manifest = os.path.join(conf_dir, 'manifest', 'init')
        self.manifest.run_initial_manifest(initial_manifest)
        self._test_output('init', 'init')


if __name__ == "__main__":
    import unittest

    unittest.main()
