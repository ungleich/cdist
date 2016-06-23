# -*- coding: utf-8 -*-
#
# 2016 Darko Poljak (darko.poljak at gmail.com)
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

import subprocess
import sys
from tempfile import TemporaryFile

import cdist

STDERR_UNSUPPORTED = 'Not supported in this python version'

def call_get_output(command, env=None):
    """Run the given command with the given environment.
    Return the tuple of stdout and stderr output as a byte strings.
    """

    assert isinstance(command, (list, tuple)), (
            "list or tuple argument expected, got: {}".format(command))

    if sys.version_info >= (3, 5):
        return call_get_out_err(command, env)
    else:
        return (call_get_stdout(command, env), STDERR_UNSUPPORTED)

def handle_called_process_error(err, command):
    if sys.version_info >= (3, 5):
        errout = err.stderr
    else:
        errout = STDERR_UNSUPPORTED
    raise cdist.Error("Command failed: " + " ".join(command)
        + " with returncode: {} and stdout: {}, stderr: {}".format(
            err.returncode, err.output, errout))

def call_get_stdout(command, env=None):
    """Run the given command with the given environment.
    Return the stdout output as a byte string, stderr is ignored.
    """
    assert isinstance(command, (list, tuple)), (
        "list or tuple argument expected, got: {}".format(command))

    with TemporaryFile() as fout:
        subprocess.check_call(command, env=env, stdout=fout)
        fout.seek(0)
        output = fout.read()

    return output

def call_get_out_err(command, env=None):
    """Run the given command with the given environment.
    Return the tuple of stdout and stderr output as a byte strings.
    """
    assert isinstance(command, (list, tuple)), (
        "list or tuple argument expected, got: {}".format(command))

    with TemporaryFile() as fout, TemporaryFile() as ferr:
        subprocess.check_call(command, env=env,
                stdout=fout, stderr=ferr)
        fout.seek(0)
        ferr.seek(0)
        output = (fout.read(), ferr.read())

    return output
