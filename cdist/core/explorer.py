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
import glob
import multiprocessing
import cdist
from cdist.mputil import mp_pool_run
from . import util

'''
common:
    runs only remotely, needs local and remote to construct paths

    env:
        __explorer: full qualified path to other global explorers on
                    remote side
            -> remote.global_explorer_path

a global explorer is:
    - a script
    - executed on the remote side
    - returns its output as a string

    env:

    creates: nothing, returns output

type explorer is:
    - a script
    - executed on the remote side for each object instance
    - returns its output as a string

    env:
        __object: full qualified path to the object's remote dir
        __object_id: the objects id
        __object_fq: full qualified object id, iow: $type.name + / + object_id
        __type_explorer: full qualified path to the other type explorers on
                         remote side

    creates: nothing, returns output

'''


class Explorer(object):
    """Executes cdist explorers.

    """
    def __init__(self, target_host, local, remote, jobs=None):
        self.target_host = target_host

        self._open_logger()

        self.local = local
        self.remote = remote
        self.env = {
            '__target_host': self.target_host[0],
            '__target_hostname': self.target_host[1],
            '__target_fqdn': self.target_host[2],
            '__explorer': self.remote.global_explorer_path,
            '__target_host_tags': self.local.target_host_tags,
            '__cdist_log_level': util.log_level_env_var_val(self.log),
            '__cdist_log_level_name': util.log_level_name_env_var_val(
                self.log),
        }
        self._type_explorers_transferred = []
        self.jobs = jobs

    def _open_logger(self):
        self.log = logging.getLogger(self.target_host[0])

    # global

    def list_global_explorer_names(self):
        """Return a list of global explorer names."""
        return glob.glob1(self.local.global_explorer_path, '*')

    def run_global_explorers(self, out_path):
        """Run global explorers and save output to files in the given
        out_path directory.

        """
        self.log.verbose("Running global explorers")
        self.transfer_global_explorers()
        if self.jobs is None:
            self._run_global_explorers_seq(out_path)
        else:
            self._run_global_explorers_parallel(out_path)

    def _run_global_explorer(self, explorer, out_path):
        output = self.run_global_explorer(explorer)
        path = os.path.join(out_path, explorer)
        with open(path, 'w') as fd:
            fd.write(output)

    def _run_global_explorers_seq(self, out_path):
        self.log.debug("Running global explorers sequentially")
        for explorer in self.list_global_explorer_names():
            self._run_global_explorer(explorer, out_path)

    def _run_global_explorers_parallel(self, out_path):
        self.log.debug("Running global explorers in {} parallel jobs".format(
            self.jobs))
        self.log.trace("Multiprocessing start method is {}".format(
            multiprocessing.get_start_method()))
        self.log.trace(("Starting multiprocessing Pool for global "
                       "explorers run"))
        args = [
            (e, out_path, ) for e in self.list_global_explorer_names()
        ]
        mp_pool_run(self._run_global_explorer, args, jobs=self.jobs)
        self.log.trace(("Multiprocessing run for global explorers "
                        "finished"))

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

    def transfer_global_explorers(self):
        """Transfer the global explorers to the remote side."""
        self.remote.transfer(self.local.global_explorer_path,
                             self.remote.global_explorer_path,
                             self.jobs)
        self.remote.run(["chmod", "0700",
                         "%s/*" % (self.remote.global_explorer_path)])

    def run_global_explorer(self, explorer):
        """Run the given global explorer and return it's output."""
        script = os.path.join(self.remote.global_explorer_path, explorer)
        return self.remote.run_script(script, env=self.env, return_output=True)

    # type

    def list_type_explorer_names(self, cdist_type):
        """Return a list of explorer names for the given type."""
        source = os.path.join(self.local.type_path, cdist_type.explorer_path)
        try:
            return glob.glob1(source, '*')
        except EnvironmentError:
            return []

    def run_type_explorers(self, cdist_object, transfer_type_explorers=True):
        """Run the type explorers for the given object and save their output
        in the object.

        """
        self.log.verbose("Running type explorers for {}".format(
            cdist_object.cdist_type))
        if transfer_type_explorers:
            self.log.trace("Transfering type explorers for type: %s",
                           cdist_object.cdist_type)
            self.transfer_type_explorers(cdist_object.cdist_type)
        else:
            self.log.trace(("No need for transfering type explorers for "
                            "type: %s"),
                           cdist_object.cdist_type)
        self.log.trace("Transfering object parameters for object: %s",
                       cdist_object.name)
        self.transfer_object_parameters(cdist_object)
        for explorer in self.list_type_explorer_names(cdist_object.cdist_type):
            output = self.run_type_explorer(explorer, cdist_object)
            self.log.trace("Running type explorer '%s' for object '%s'",
                           explorer, cdist_object.name)
            cdist_object.explorers[explorer] = output

    def run_type_explorer(self, explorer, cdist_object):
        """Run the given type explorer for the given object and return
           it's output."""
        cdist_type = cdist_object.cdist_type
        env = self.env.copy()
        env.update({
            '__object': os.path.join(self.remote.object_path,
                                     cdist_object.path),
            '__object_id': cdist_object.object_id,
            '__object_name': cdist_object.name,
            '__object_fq': cdist_object.path,
            '__type_explorer': os.path.join(self.remote.type_path,
                                            cdist_type.explorer_path)
        })
        script = os.path.join(self.remote.type_path, cdist_type.explorer_path,
                              explorer)
        return self.remote.run_script(script, env=env, return_output=True)

    def transfer_type_explorers(self, cdist_type):
        """Transfer the type explorers for the given type to the
           remote side."""
        if cdist_type.explorers:
            if cdist_type.name in self._type_explorers_transferred:
                self.log.trace(("Skipping retransfer of type explorers "
                                "for: %s"), cdist_type)
            else:
                source = os.path.join(self.local.type_path,
                                      cdist_type.explorer_path)
                destination = os.path.join(self.remote.type_path,
                                           cdist_type.explorer_path)
                self.remote.transfer(source, destination)
                self.remote.run(["chmod", "0700", "%s/*" % (destination)])
                self._type_explorers_transferred.append(cdist_type.name)

    def transfer_object_parameters(self, cdist_object):
        """Transfer the parameters for the given object to the remote side."""
        if cdist_object.parameters:
            source = os.path.join(self.local.object_path,
                                  cdist_object.parameter_path)
            destination = os.path.join(self.remote.object_path,
                                       cdist_object.parameter_path)
            self.remote.transfer(source, destination)
