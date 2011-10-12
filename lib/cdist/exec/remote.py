# -*- coding: utf-8 -*-
#
# 2011 Steven Armstrong (steven-cdist at armstrong.cc)
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

# FIXME: common base class with Local?

import io
import os
import sys
import subprocess
import logging

import cdist


class RemoteScriptError(cdist.Error):
    def __init__(self, script, command, script_content):
        self.script = script
        self.command = command
        self.script_content = script_content

    def __str__(self):
        return "Remote script execution failed: %s %s" % (self.script, self.command)


class Remote(object):
    """Execute commands remotely.

    All interaction with the remote side should be done through this class.
    Directly accessing the remote side from python code is a bug.

    """
    def __init__(self, target_host, remote_base_path, remote_exec, remote_copy):
        self.target_host = target_host
        self.base_path = remote_base_path
        self._exec = remote_exec
        self._copy = remote_copy

        self.conf_path = os.path.join(self.base_path, "conf")
        self.object_path = os.path.join(self.base_path, "object")

        self.type_path = os.path.join(self.conf_path, "type")
        self.global_explorer_path = os.path.join(self.conf_path, "explorer")

        self.log = logging.getLogger(self.target_host)
    
    def create_directories(self):
        self.rmdir(self.base_path)
        self.mkdir(self.base_path)
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
        command = self._copy.split()
        command.extend(["-r", source, self.target_host + ":" + destination])
        self.run_command(command)

    def run(self, command, env=None):
        """Run the given command with the given environment on the remote side.
        Return the output as a string.

        """
        # prefix given command with remote_exec
        cmd = self._exec.split()
        cmd.append(self.target_host)
        cmd.extend(command)
        return self.run_command(cmd, env=None)

    def run_command(self, command, env=None):
        """Run the given command with the given environment.
        Return the output as a string.

        """
        assert isinstance(command, (list, tuple)), "list or tuple argument expected, got: %s" % command
        self.log.debug("Remote run: %s", command)
        try:
            return subprocess.check_output(command, env=env)
        except subprocess.CalledProcessError:
            raise cdist.Error("Command failed: " + " ".join(command))
        except OSError as error:
            raise cdist.Error(" ".join(*args) + ": " + error.args[1])

    def run_script(self, script, env=None):
        """Run the given script with the given environment on the remote side.
        Return the output as a string.

        """
        command = self._exec.split()
        command.append(self.target_host)
        command.extend(["/bin/sh", "-e"])
        command.append(script)

        self.log.debug("Remote run script: %s", command)
        if env:
            self.log.debug("Remote run script env: %s", env)
        
        try:
            return subprocess.check_output(command, env=env)
        except subprocess.CalledProcessError as error:
            script_content = self.run(["cat", script])
            self.log.error("Code that raised the error:\n%s", script_content)
            raise RemoteScriptError(script, command, script_content)
        except EnvironmentError as error:
            raise cdist.Error(" ".join(command) + ": " + error.args[1])
