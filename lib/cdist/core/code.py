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

import logging
import os

import cdist

log = logging.getLogger(__name__)


'''
common:
    runs only locally, does not need remote

    env:
        PATH: prepend directory with type emulator symlinks == local.bin_path
        __target_host: the target host we are working on
        __cdist_manifest: full qualified path of the manifest == script
        __cdist_type_base_path: full qualified path to the directory where types are defined for use in type emulator
            == local.type_path

gencode-local
    script: full qualified path to a types gencode-local

    env:
        __target_host: the target host we are working on
        __global: full qualified path to the global output dir == local.out_path
        __object: full qualified path to the object's dir
        __object_id: the objects id
        __object_fq: full qualified object id, iow: $type.name + / + object_id
        __type: full qualified path to the type's dir

    returns: string containing the generated code or None

gencode-remote
    script: full qualified path to a types gencode-remote

    env:
        __target_host: the target host we are working on
        __global: full qualified path to the global output dir == local.out_path
        __object: full qualified path to the object's dir
        __object_id: the objects id
        __object_fq: full qualified object id, iow: $type.name + / + object_id
        __type: full qualified path to the type's dir

    returns: string containing the generated code or None


code-local
    script: full qualified path to object's code-local
    - run script localy
    returns: string containing the output

code-remote
    script: full qualified path to object's code-remote
    - copy script to remote
    - run script remotely
    returns: string containing the output
'''


class Code(object):
    """Generates and executes cdist code scripts.

    """
    def __init__(self, target_host, local, remote):
        self.target_host = target_host
        self.local = local
        self.remote = remote
        self.env = {
            '__target_host': self.target_host,
            '__global': self.local.out_path,
        }

    def _run_gencode(self, cdist_object, which):
        cdist_type = cdist_object.cdist_type
        script = os.path.join(self.local.type_path, getattr(cdist_type, 'gencode_%s_path' % which))
        if os.path.isfile(script):
            env = os.environ.copy()
            env.update(self.env)
            env.update({
                '__type': cdist_object.cdist_type.absolute_path,
                '__object': cdist_object.absolute_path,
                '__object_id': cdist_object.object_id,
                '__object_name': cdist_object.name,
            })
            return self.local.run_script(script, env=env, return_output=True)

    def run_gencode_local(self, cdist_object):
        """Run the gencode-local script for the given cdist object."""
        return self._run_gencode(cdist_object, 'local')

    def run_gencode_remote(self, cdist_object):
        """Run the gencode-remote script for the given cdist object."""
        return self._run_gencode(cdist_object, 'remote')

    def transfer_code_remote(self, cdist_object):
        """Transfer the code_remote script for the given object to the remote side."""
        source = os.path.join(self.local.object_path, cdist_object.code_remote_path)
        destination = os.path.join(self.remote.object_path, cdist_object.code_remote_path)
        # FIXME: BUG: do not create destination, but top level of destination!
        # FIXME: BUG2: we are called AFTER the code-remote has been transferred already:
        # mkdir: cannot create directory `/var/lib/cdist/object/__directory/etc/acpi/actions/.cdist/code-remote': File exists
        # OR: this is from previous run -> cleanup missing!
        self.remote.mkdir(destination)
        self.remote.transfer(source, destination)

    def _run_code(self, cdist_object, which):
        which_exec = getattr(self, which)
        script = os.path.join(which_exec.object_path, getattr(cdist_object, 'code_%s_path' % which))
        return which_exec.run_script(script)

    def run_code_local(self, cdist_object):
        """Run the code-local script for the given cdist object."""
        return self._run_code(cdist_object, 'local')

    def run_code_remote(self, cdist_object):
        """Run the code-remote script for the given cdist object on the remote side."""
        return self._run_code(cdist_object, 'remote')
