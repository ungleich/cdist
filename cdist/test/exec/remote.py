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
import getpass
import shutil
import multiprocessing

import cdist
from cdist import test
from cdist.exec import remote


class RemoteTestCase(test.CdistTestCase):

    def setUp(self):
        self.temp_dir = self.mkdtemp()
        self.target_host = (
            'localhost',
            'localhost',
            'localhost',
        )
        # another temp dir for remote base path
        self.base_path = self.mkdtemp()
        self.remote = self.create_remote()

    def create_remote(self, *args, **kwargs):
        if not args:
            args = (self.target_host,)
        kwargs.setdefault('base_path', self.base_path)
        user = getpass.getuser()
        kwargs.setdefault('remote_exec', 'ssh -o User=%s -q' % user)
        kwargs.setdefault('remote_copy', 'scp -o User=%s -q' % user)
        if 'stdout_base_path' not in kwargs:
            stdout_path = os.path.join(self.temp_dir, 'stdout')
            os.makedirs(stdout_path, exist_ok=True)
            kwargs['stdout_base_path'] = stdout_path
        if 'stderr_base_path' not in kwargs:
            stderr_path = os.path.join(self.temp_dir, 'stderr')
            os.makedirs(stderr_path, exist_ok=True)
            kwargs['stderr_base_path'] = stderr_path
        return remote.Remote(*args, **kwargs)

    def tearDown(self):
        shutil.rmtree(self.temp_dir)
        shutil.rmtree(self.base_path)

    # test api

    def test_conf_path(self):
        self.assertEqual(self.remote.conf_path,
                         os.path.join(self.base_path, "conf"))

    def test_object_path(self):
        self.assertEqual(self.remote.object_path,
                         os.path.join(self.base_path, "object"))

    def test_type_path(self):
        self.assertEqual(self.remote.type_path,
                         os.path.join(self.base_path, "conf", "type"))

    def test_global_explorer_path(self):
        self.assertEqual(self.remote.global_explorer_path,
                         os.path.join(self.base_path, "conf", "explorer"))

    # /test api

    def test_run_success(self):
        self.remote.run(['true'])

    def test_run_fail(self):
        self.assertRaises(cdist.Error, self.remote.run, ['false'])

    def test_run_script_success(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", "true"])
        self.remote.run_script(script)

    def test_run_script_fail(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", "false"])
        self.assertRaises(cdist.Error, self.remote.run_script,
                          script)

    def test_run_script_get_output(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", "echo foobar"])
        self.assertEqual(self.remote.run_script(script, return_output=True),
                         "foobar\n")

    def test_mkdir(self):
        temp_dir = self.mkdtemp(dir=self.temp_dir)
        os.rmdir(temp_dir)
        self.remote.mkdir(temp_dir)
        self.assertTrue(os.path.isdir(temp_dir))

    def test_rmdir(self):
        temp_dir = self.mkdtemp(dir=self.temp_dir)
        self.remote.rmdir(temp_dir)
        self.assertFalse(os.path.isdir(temp_dir))

    def test_transfer_file(self):
        handle, source = self.mkstemp(dir=self.temp_dir)
        os.close(handle)
        target = self.mkdtemp(dir=self.temp_dir)
        self.remote.transfer(source, target)
        self.assertTrue(os.path.isfile(
            os.path.join(target, os.path.basename(source))))

    def test_transfer_dir(self):
        source = self.mkdtemp(dir=self.temp_dir)
        # put a file in the directory as payload
        handle, source_file = self.mkstemp(dir=source)
        os.close(handle)
        source_file_name = os.path.split(source_file)[-1]
        target = self.mkdtemp(dir=self.temp_dir)
        self.remote.transfer(source, target)
        # test if the payload file is in the target directory
        self.assertTrue(os.path.isfile(os.path.join(target, source_file_name)))

    def test_transfer_dir_parallel(self):
        source = self.mkdtemp(dir=self.temp_dir)
        # put 8 files in the directory as payload
        filenames = []
        for x in range(8):
            handle, source_file = self.mkstemp(dir=source)
            os.close(handle)
            source_file_name = os.path.split(source_file)[-1]
            filenames.append(source_file_name)
        target = self.mkdtemp(dir=self.temp_dir)
        self.remote.transfer(source, target,
                             multiprocessing.cpu_count())
        # test if the payload files are in the target directory
        for filename in filenames:
            self.assertTrue(os.path.isfile(os.path.join(target, filename)))

    def test_create_files_dirs(self):
        self.remote.create_files_dirs()
        self.assertTrue(os.path.isdir(self.remote.base_path))
        self.assertTrue(os.path.isdir(self.remote.conf_path))

    def test_run_target_host_in_env(self):
        handle, remote_exec_path = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, 'w') as fd:
            fd.writelines(["#!/bin/sh\n", "echo $__target_host"])
        os.chmod(remote_exec_path, 0o755)
        remote_exec = remote_exec_path
        remote_copy = "echo"
        r = self.create_remote(remote_exec=remote_exec,
                               remote_copy=remote_copy)
        self.assertEqual(r.run('true', return_output=True),
                         "%s\n" % self.target_host[0])

    def test_run_script_target_host_in_env(self):
        handle, remote_exec_path = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, 'w') as fd:
            fd.writelines(["#!/bin/sh\n", "echo $__target_host"])
        os.chmod(remote_exec_path, 0o755)
        remote_exec = remote_exec_path
        remote_copy = "echo"
        r = self.create_remote(remote_exec=remote_exec,
                               remote_copy=remote_copy)
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines(["#!/bin/sh\n", "true"])
        self.assertEqual(r.run_script(script, return_output=True),
                         "%s\n" % self.target_host[0])

    def test_run_script_with_env_target_host_in_env(self):
        handle, script = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, "w") as fd:
            fd.writelines([
                "#!/bin/sh\n",
                ('if [ "$__object" ]; then echo $__object; '
                 'else echo no_env; fi\n')])
        os.chmod(script, 0o755)
        handle, remote_exec_path = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, 'w') as fd:
            fd.writelines(["#!/bin/sh\n", 'shift; cmd=$1; shift; $cmd "$@"\n'])
        os.chmod(remote_exec_path, 0o755)
        remote_exec = remote_exec_path
        remote_copy = "echo"
        r = self.create_remote(remote_exec=remote_exec,
                               remote_copy=remote_copy)
        output = r.run_script(script, return_output=True)
        self.assertEqual(output, "no_env\n")

        handle, remote_exec_path = self.mkstemp(dir=self.temp_dir)
        with os.fdopen(handle, 'w') as fd:
            fd.writelines(["#!/bin/sh\n", 'shift; cmd=$1; eval $cmd\n'])
        os.chmod(remote_exec_path, 0o755)
        remote_exec = remote_exec_path
        env = {
            '__object': 'test_object',
        }
        r = self.create_remote(remote_exec=remote_exec,
                               remote_copy=remote_copy)
        output = r.run_script(script, env=env, return_output=True)
        self.assertEqual(output, "test_object\n")


if __name__ == '__main__':
    import unittest

    unittest.main()
