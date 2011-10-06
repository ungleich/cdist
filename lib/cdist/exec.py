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
import os
import subprocess

log = logging.getLogger(__name__)

import cdist

def shell_run_or_debug_fail(script, *args, remote_prefix=False, **kargs):
    # Manually execute /bin/sh, because sh -e does what we want
    # and sh -c -e does not exit if /bin/false called
    args[0][:0] = [ "/bin/sh", "-e" ]

    if remote_prefix:
        args[0][:0] = os.environ['__remote_exec']

    log.debug("Shell exec cmd: %s", args)

    if 'env' in kargs:
        log.debug("Shell exec env: %s", kargs['env'])

    try:
        subprocess.check_call(*args, **kargs)
    except subprocess.CalledProcessError:
        log.error("Code that raised the error:\n")

        if remote_prefix:
            run_or_fail(["cat", script], remote_prefix=remote_prefix)

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

def run_or_fail(*args, remote_prefix=False, **kargs):
    if remote_prefix:
        args[0][:0] = os.environ['__remote_exec']

    log.debug("Exec: " + " ".join(*args))
    try:
        subprocess.check_call(*args, **kargs)
    except subprocess.CalledProcessError:
        raise cdist.Error("Command failed: " + " ".join(*args))
    except OSError as error:
        raise cdist.Error(" ".join(*args) + ": " + error.args[1])
