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
import multiprocessing

import cdist
import cdist.exec.util as exec_util
import cdist.util.ipaddr as ipaddr
from cdist.mputil import mp_pool_run


def _wrap_addr(addr):
    """If addr is IPv6 then return addr wrapped between '[' and ']',
    otherwise return it intact."""
    if ipaddr.is_ipv6(addr):
        return "".join(("[", addr, "]", ))
    else:
        return addr


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

        self._open_logger()

        self._init_env()

    def _open_logger(self):
        self.log = logging.getLogger(self.target_host[0])

    # logger is not pickable, so remove it when we pickle
    def __getstate__(self):
        state = self.__dict__.copy()
        if 'log' in state:
            del state['log']
        return state

    # recreate logger when we unpickle
    def __setstate__(self, state):
        self.__dict__.update(state)
        self._open_logger()

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

    def transfer(self, source, destination, jobs=None):
        """Transfer a file or directory to the remote side."""
        self.log.debug("Remote transfer: %s -> %s", source, destination)
        self.rmdir(destination)
        if os.path.isdir(source):
            self.mkdir(destination)
            if jobs:
                self._transfer_dir_parallel(source, destination, jobs)
            else:
                self._transfer_dir_sequential(source, destination)
        elif jobs:
            raise cdist.Error("Source {} is not a directory".format(source))
        else:
            command = self._copy.split()
            command.extend([source, '{0}:{1}'.format(
                _wrap_addr(self.target_host[0]), destination)])
            self._run_command(command)

    def _transfer_dir_sequential(self, source, destination):
        for f in glob.glob1(source, '*'):
            command = self._copy.split()
            path = os.path.join(source, f)
            command.extend([path, '{0}:{1}'.format(
                _wrap_addr(self.target_host[0]), destination)])
            self._run_command(command)

    def _transfer_dir_parallel(self, source, destination, jobs):
        """Transfer a directory to the remote side in parallel mode."""
        self.log.info("Remote transfer in {} parallel jobs".format(
            jobs))
        self.log.debug("Multiprocessing start method is {}".format(
            multiprocessing.get_start_method()))
        self.log.debug(("Starting multiprocessing Pool for parallel "
                        "remote transfer"))
        args = []
        for f in glob.glob1(source, '*'):
            command = self._copy.split()
            path = os.path.join(source, f)
            command.extend([path, '{0}:{1}'.format(
                _wrap_addr(self.target_host[0]), destination)])
            args.append((command, ))
        mp_pool_run(self._run_command, args, jobs=jobs)
        self.log.debug(("Multiprocessing for parallel transfer "
                        "finished"))

    def run_script(self, script, env=None, return_output=False):
        """Run the given script with the given environment on the remote side.
        Return the output as a string.

        """

        command = [os.environ.get('CDIST_REMOTE_SHELL', "/bin/sh"), "-e"]
        command.append(script)

        return self.run(command, env, return_output)

    def run(self, command, env=None, return_output=False):
        """Run the given command with the given environment on the remote side.
        Return the output as a string.

        """
        # prefix given command with remote_exec
        cmd = self._exec.split()
        cmd.append(self.target_host[0])

        # FIXME: replace this by -o SendEnv name -o SendEnv name ... to ssh?
        # can't pass environment to remote side, so prepend command with
        # variable declarations

        # cdist command prepended with variable assignments expects
        # posix shell (bourne, bash) at the remote as user default shell.
        # If remote user shell isn't poxis shell, but for e.g. csh/tcsh
        # then these var assignments are not var assignments for this
        # remote shell, it tries to execute it as a command and fails.
        # So really do this by default:
        # /bin/sh -c 'export <var assignments>; command'
        # so that constructed remote command isn't dependent on remote
        # shell. Do this only if env is not None. env breaks this.
        # Explicitly use /bin/sh, because var assignments assume poxis
        # shell already.
        # This leaves the posibility to write script that needs to be run
        # remotely in e.g. csh and setting up CDIST_REMOTE_SHELL to e.g.
        # /bin/csh will execute this script in the right way.
        if env:
            remote_env = [" export %s=%s;" % item for item in env.items()]
            string_cmd = ("/bin/sh -c '" + " ".join(remote_env) +
                          " ".join(command) + "'")
            cmd.append(string_cmd)
        else:
            cmd.extend(command)
        return self._run_command(cmd, env=env, return_output=return_output)

    def _run_command(self, command, env=None, return_output=False):
        """Run the given command with the given environment.
        Return the output as a string.

        """
        assert isinstance(command, (list, tuple)), (
                "list or tuple argument expected, got: %s" % command)

        # export target_host, target_hostname, target_fqdn
        # for use in __remote_{exec,copy} scripts
        os_environ = os.environ.copy()
        os_environ['__target_host'] = self.target_host[0]
        os_environ['__target_hostname'] = self.target_host[1]
        os_environ['__target_fqdn'] = self.target_host[2]

        self.log.debug("Remote run: %s", command)
        try:
            output, errout = exec_util.call_get_output(command, env=os_environ)
            self.log.debug("Remote stdout: {}".format(output))
            # Currently, stderr is not captured.
            # self.log.debug("Remote stderr: {}".format(errout))
            if return_output:
                return output.decode()
        except subprocess.CalledProcessError as e:
            exec_util.handle_called_process_error(e, command)
        except OSError as error:
            raise cdist.Error(" ".join(command) + ": " + error.args[1])
        except UnicodeDecodeError:
            raise DecodeError(command)
