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


def shell_run_or_debug_fail(script, *args, **kargs):
    # Manually execute /bin/sh, because sh -e does what we want
    # and sh -c -e does not exit if /bin/false called
    args[0][:0] = [ "/bin/sh", "-e" ]

    remote = False
    if "remote" in kargs:
        if kargs["remote"]:
            args[0][:0] = kargs["remote_prefix"]
            remote = true

        del kargs["remote"]
        del kargs["remote_prefix"]

    log.debug("Shell exec cmd: %s", args)
    log.debug("Shell exec env: %s", kargs['env'])
    try:
        subprocess.check_call(*args, **kargs)
    except subprocess.CalledProcessError:
        log.error("Code that raised the error:\n")
        if remote:
            remote_cat(script)
        else:
            try:
                script_fd = open(script)
                print(script_fd.read())
                script_fd.close()
            except IOError as error:
                raise CdistError(str(error))

        raise CdistError("Command failed (shell): " + " ".join(*args))
    except OSError as error:
        raise CdistError(" ".join(*args) + ": " + error.args[1])


def run_or_fail(self, *args, **kargs):
    if "remote" in kargs:
        if kargs["remote"]:
            args[0][:0] = kargs["remote_prefix"]

        del kargs["remote"]
        del kargs["remote_prefix"]

    log.debug("Exec: " + " ".join(*args))
    try:
        subprocess.check_call(*args, **kargs)
    except subprocess.CalledProcessError:
        raise CdistError("Command failed: " + " ".join(*args))
    except OSError as error:
        raise CdistError(" ".join(*args) + ": " + error.args[1])
