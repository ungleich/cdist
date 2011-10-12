# -*- coding: utf-8 -*-
#
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

import logging
import subprocess

import cdist


class Wrapper(object):
    def __init__(self, target_host, remote_exec, remote_copy):
        self.target_host = target_host
        self.remote_exec = remote_exec
        self.remote_copy = remote_copy
        self.log = logging.getLogger(self.target_host)

    def remote_mkdir(self, directory):
        """Create directory on remote side"""
        self.run_or_fail(["mkdir", "-p", directory], remote=True)

    def remove_remote_path(self, destination):
        """Ensure path on remote side vanished"""
        self.run_or_fail(["rm", "-rf",  destination], remote=True)

    def transfer_path(self, source, destination):
        """Transfer directory and previously delete the remote destination"""
        self.remove_remote_path(destination)
        self.run_or_fail(self.remote_copy.split() +
            ["-r", source, self.target_host + ":" + destination])

    def shell_run_or_debug_fail(self, script, *args, remote=False, **kargs):
        # Manually execute /bin/sh, because sh -e does what we want
        # and sh -c -e does not exit if /bin/false called
        args[0][:0] = [ "/bin/sh", "-e" ]

        if remote:
            remote_prefix = self.remote_exec.split()
            remote_prefix.append(self.target_host)
            args[0][:0] = remote_prefix

        self.log.debug("Shell exec cmd: %s", args)

        if 'env' in kargs:
            self.log.debug("Shell exec env: %s", kargs['env'])

        try:
            subprocess.check_call(*args, **kargs)
        except subprocess.CalledProcessError:
            self.log.error("Code that raised the error:\n")

            if remote:
                self.run_or_fail(["cat", script], remote=remote)

            else:
                try:
                    script_fd = open(script)
                    print(script_fd.read())
                    script_fd.close()
                except IOError as error:
                    raise cdist.Error(str(error))

            raise cdist.Error("Command failed (shell): " + " ".join(*args))
        except OSError as error:
            raise cdist.Error(" ".join(*args) + ": " + error.args[1])

    def run_or_fail(self, *args, remote=False, **kargs):
        if remote:
            remote_prefix = self.remote_exec.split()
            remote_prefix.append(self.target_host)
            args[0][:0] = remote_prefix

        self.log.debug("Exec: " + " ".join(*args))
        try:
            subprocess.check_call(*args, **kargs)
        except subprocess.CalledProcessError:
            raise cdist.Error("Command failed: " + " ".join(*args))
        except OSError as error:
            raise cdist.Error(" ".join(*args) + ": " + error.args[1])
