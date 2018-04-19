# -*- coding: utf-8 -*-
#
# 2011-2017 Steven Armstrong (steven-cdist at armstrong.cc)
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

import os
import glob
import subprocess
import logging
import multiprocessing

import cdist
import cdist.exec.util as util
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
                 base_path=None,
                 quiet_mode=None,
                 archiving_mode=None,
                 configuration=None,
                 stdout_base_path=None,
                 stderr_base_path=None,
                 save_output_streams=True):
        self.target_host = target_host
        self._exec = remote_exec
        self._copy = remote_copy

        if base_path:
            self.base_path = base_path
        else:
            self.base_path = "/var/lib/cdist"
        self.quiet_mode = quiet_mode
        self.archiving_mode = archiving_mode
        if configuration:
            self.configuration = configuration
        else:
            self.configuration = {}
        self.save_output_streams = save_output_streams

        self.stdout_base_path = stdout_base_path
        self.stderr_base_path = stderr_base_path

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
        """Setup environment for scripts."""
        # FIXME: better do so in exec functions that require it!
        os.environ['__remote_copy'] = self._copy
        os.environ['__remote_exec'] = self._exec

    def create_files_dirs(self):
        self.rmdir(self.base_path)
        self.mkdir(self.base_path)
        self.run(["chmod", "0700", self.base_path])
        self.mkdir(self.conf_path)

    def remove_files_dirs(self):
        self.rmdir(self.base_path)

    def rmfile(self, path):
        """Remove file on the remote side."""
        self.log.trace("Remote rm: %s", path)
        self.run(["rm", "-f",  path])

    def rmdir(self, path):
        """Remove directory on the remote side."""
        self.log.trace("Remote rmdir: %s", path)
        self.run(["rm", "-rf",  path])

    def mkdir(self, path):
        """Create directory on the remote side."""
        self.log.trace("Remote mkdir: %s", path)
        self.run(["mkdir", "-p", path])

    def extract_archive(self, path, mode):
        """Extract archive path on the remote side."""
        import cdist.autil as autil

        self.log.trace("Remote extract archive: %s", path)
        command = ["tar", "-x", "-m", "-C", ]
        directory = os.path.dirname(path)
        command.append(directory)
        xopt = autil.get_extract_option(mode)
        if xopt:
            command.append(xopt)
        command.append("-f")
        command.append(path)
        self.run(command)

    def _transfer_file(self, source, destination):
        command = self._copy.split()
        command.extend([source, '{0}:{1}'.format(
            _wrap_addr(self.target_host[0]), destination)])
        self._run_command(command)

    def transfer(self, source, destination, jobs=None):
        """Transfer a file or directory to the remote side."""
        self.log.trace("Remote transfer: %s -> %s", source, destination)
        # self.rmdir(destination)
        if os.path.isdir(source):
            self.mkdir(destination)
            used_archiving = False
            if self.archiving_mode:
                self.log.trace("Remote transfer in archiving mode")
                import cdist.autil as autil

                # create archive
                tarpath, fcnt = autil.tar(source, self.archiving_mode)
                if tarpath is None:
                    self.log.trace(("Files count {} is lower than {} limit, "
                                    "skipping archiving").format(
                                        fcnt, autil.FILES_LIMIT))
                else:
                    self.log.trace(("Archiving mode, tarpath: %s, file count: "
                                    "%s"), tarpath, fcnt)
                    # get archive name
                    tarname = os.path.basename(tarpath)
                    self.log.trace("Archiving mode tarname: %s", tarname)
                    # archive path at the remote
                    desttarpath = os.path.join(destination, tarname)
                    self.log.trace(
                        "Archiving mode desttarpath: %s", desttarpath)
                    # transfer archive to the remote side
                    self.log.trace("Archiving mode: transfering")
                    self._transfer_file(tarpath, desttarpath)
                    # extract archive at the remote
                    self.log.trace("Archiving mode: extracting")
                    self.extract_archive(desttarpath, self.archiving_mode)
                    # remove remote archive
                    self.log.trace("Archiving mode: removing remote archive")
                    self.rmfile(desttarpath)
                    # remove local archive
                    self.log.trace("Archiving mode: removing local archive")
                    os.remove(tarpath)
                    used_archiving = True
            if not used_archiving:
                if jobs:
                    self._transfer_dir_parallel(source, destination, jobs)
                else:
                    self._transfer_dir_sequential(source, destination)
        elif jobs:
            raise cdist.Error("Source {} is not a directory".format(source))
        else:
            self._transfer_file(source, destination)

    def _transfer_dir_commands(self, source, destination):
        for f in glob.glob1(source, '*'):
            command = self._copy.split()
            path = os.path.join(source, f)
            command.extend([path, '{0}:{1}'.format(
                _wrap_addr(self.target_host[0]), destination)])
            yield command

    def _transfer_dir_sequential(self, source, destination):
        for command in self._transfer_dir_commands(source, destination):
            self._run_command(command)

    def _transfer_dir_parallel(self, source, destination, jobs):
        """Transfer a directory to the remote side in parallel mode."""
        self.log.debug("Remote transfer in {} parallel jobs".format(
            jobs))
        self.log.trace("Multiprocessing start method is {}".format(
            multiprocessing.get_start_method()))
        self.log.trace(("Starting multiprocessing Pool for parallel "
                        "remote transfer"))
        args = [
            (command, )
            for command in self._transfer_dir_commands(source, destination)
        ]
        if len(args) == 1:
            self.log.debug("Only one dir entry, transfering sequentially")
            self._run_command(args[0])
        else:
            mp_pool_run(self._run_command, args, jobs=jobs)
        self.log.trace(("Multiprocessing for parallel transfer "
                        "finished"))

    def run_script(self, script, env=None, return_output=False, stdout=None,
                   stderr=None):
        """Run the given script with the given environment on the remote side.
        Return the output as a string.

        """

        command = [
            self.configuration.get('remote_shell', "/bin/sh"),
            "-e"
        ]
        command.append(script)

        return self.run(command, env=env, return_output=return_output,
                        stdout=stdout, stderr=stderr)

    def run(self, command, env=None, return_output=False, stdout=None,
            stderr=None):
        """Run the given command with the given environment on the remote side.
        Return the output as a string.

        """
        # prefix given command with remote_exec
        cmd = self._exec.split()
        cmd.append(self.target_host[0])

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
        return self._run_command(cmd, env=env, return_output=return_output,
                                 stdout=stdout, stderr=stderr)

    def _run_command(self, command, env=None, return_output=False, stdout=None,
                     stderr=None):
        """Run the given command with the given environment.
        Return the output as a string.

        """
        assert isinstance(command, (list, tuple)), (
                "list or tuple argument expected, got: %s" % command)

        if return_output and stdout is not subprocess.PIPE:
            self.log.debug("return_output is True, ignoring stdout")

        close_stdout = False
        close_stderr = False
        if self.save_output_streams:
            if not return_output and stdout is None:
                stdout = util.get_std_fd(self.stdout_base_path, 'remote')
                close_stdout = True
            if stderr is None:
                stderr = util.get_std_fd(self.stderr_base_path, 'remote')
                close_stderr = True

        # export target_host, target_hostname, target_fqdn
        # for use in __remote_{exec,copy} scripts
        os_environ = os.environ.copy()
        os_environ['__target_host'] = self.target_host[0]
        os_environ['__target_hostname'] = self.target_host[1]
        os_environ['__target_fqdn'] = self.target_host[2]

        self.log.trace("Remote run: %s", command)
        try:
            if self.quiet_mode:
                stderr = subprocess.DEVNULL
            if return_output:
                output = subprocess.check_output(command, env=os_environ,
                                                 stderr=stderr).decode()
            else:
                subprocess.check_call(command, env=os_environ, stdout=stdout,
                                      stderr=stderr)
                output = None

            if self.save_output_streams:
                util.log_std_fd(self.log, command, stderr, 'Remote stderr')
                util.log_std_fd(self.log, command, stdout, 'Remote stdout')

            return output
        except (OSError, subprocess.CalledProcessError) as error:
            raise cdist.Error(" ".join(command) + ": " + str(error.args[1]))
        except UnicodeDecodeError:
            raise DecodeError(command)
        finally:
            if close_stdout:
                stdout.close()
            if close_stderr:
                stderr.close()
