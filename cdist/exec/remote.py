# -*- coding: utf-8 -*-
#
# 2011 Steven Armstrong (steven-cdist at armstrong.cc)
# 2011-2013 Nico Schottelius (nico-cdist at schottelius.org)
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
import os
import sys
import glob
import subprocess
import logging

import cdist

class DecodeError(cdist.Error):
    def __init__(self, command):
        self.command = command

    def __str__(self):
        return "Cannot decode output of " + " ".join(self.command)


class Remote(object):
    """Execute commands remotely.

    All interaction with the remote side should be done through this class.
    Directly accessing the remote side from python code is a bug.

    """
    def __init__(self,
                 target_host,
                 remote_exec,
                 remote_copy,
                 base_path=None):
        self.target_host = target_host
        self._exec = remote_exec
        self._copy = remote_copy

        if base_path:
            self.base_path = base_path
        else:
            self.base_path = "/var/lib/cdist"

        self.conf_path = os.path.join(self.base_path, "conf")
        self.object_path = os.path.join(self.base_path, "object")

        self.type_path = os.path.join(self.conf_path, "type")
        self.global_explorer_path = os.path.join(self.conf_path, "explorer")

        self.log = logging.getLogger(self.target_host)

        self._init_env()

    def _init_env(self):
        """Setup environment for scripts - HERE????"""
        # FIXME: better do so in exec functions that require it!
        os.environ['__remote_copy'] = self._copy
        os.environ['__remote_exec'] = self._exec


    def create_files_dirs(self):
        self.rmdir(self.base_path)
        self.mkdir(self.base_path)
        self.run(["chmod", "0700", self.base_path])
        self.mkdir(self.conf_path)

    def rmdir(self, path):
        """Remove directory on the remote side."""
        self.log.debug("Remote rmdir: %s", path)
        self.run(["rm", "-rf",  path])

    def mkdir(self, path):
        """Create directory on the remote side."""
        self.log.debug("Remote mkdir: %s", path)
        self.run(["mkdir", "-p", path])

    def transfer(self, source, destination):
        """Transfer a file or directory to the remote side."""
        self.log.debug("Remote transfer: %s -> %s", source, destination)
        self.rmdir(destination)
        if os.path.isdir(source):
            self.mkdir(destination)
            for f in glob.glob1(source, '*'):
                command = self._copy.split()
                path = os.path.join(source, f)
                command.extend([path, '{0}:{1}'.format(self.target_host, destination)])
                self._run_command(command)
        else:
            command = self._copy.split()
            command.extend([source, '{0}:{1}'.format(self.target_host, destination)])
            self._run_command(command)

    def run_script(self, script, env=None, return_output=False):
        """Run the given script with the given environment on the remote side.
        Return the output as a string.

        """

        command = [ os.environ.get('CDIST_REMOTE_SHELL',"/bin/sh") , "-e"]
        command.append(script)

        return self.run(command, env, return_output)

    def run(self, command, env=None, return_output=False):
        """Run the given command with the given environment on the remote side.
        Return the output as a string.

        """
        # prefix given command with remote_exec
        cmd = self._exec.split()
        cmd.append(self.target_host)

        # FIXME: replace this by -o SendEnv name -o SendEnv name ... to ssh?
        # can't pass environment to remote side, so prepend command with
        # variable declarations
        if env:
            remote_env = ["%s=%s" % item for item in env.items()]
            cmd.extend(remote_env)

        cmd.extend(command)

        return self._run_command(cmd, env=env, return_output=return_output)

    def _run_command(self, command, env=None, return_output=False):
        """Run the given command with the given environment.
        Return the output as a string.

        """
        assert isinstance(command, (list, tuple)), "list or tuple argument expected, got: %s" % command

        # export target_host for use in __remote_{exec,copy} scripts
        os_environ = os.environ.copy()
        os_environ['__target_host'] = self.target_host

        self.log.debug("Remote run: %s", command)
        try:
            if return_output:
                return subprocess.check_output(command, env=os_environ).decode()
            else:
                subprocess.check_call(command, env=os_environ)
        except subprocess.CalledProcessError:
            raise cdist.Error("Command failed: " + " ".join(command))
        except OSError as error:
            raise cdist.Error(" ".join(command) + ": " + error.args[1])
        except UnicodeDecodeError:
            raise DecodeError(command)
