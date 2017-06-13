#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2010-2015 Nico Schottelius (nico-cdist at schottelius.org)
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
import sys
import time
import itertools
import tempfile
import socket
import multiprocessing
from cdist.mputil import mp_pool_run
import atexit
import shutil

import cdist
import cdist.hostsource

import cdist.exec.local
import cdist.exec.remote
import cdist.util.ipaddr as ipaddr

from cdist import core
from cdist.util.remoteutil import inspect_ssh_mux_opts


class Config(object):
    """Cdist main class to hold arbitrary data"""

    def __init__(self, local, remote, dry_run=False, jobs=None):

        self.local = local
        self.remote = remote
        self._open_logger()
        self.dry_run = dry_run
        self.jobs = jobs

        self.explorer = core.Explorer(self.local.target_host, self.local,
                                      self.remote, jobs=self.jobs)
        self.manifest = core.Manifest(self.local.target_host, self.local)
        self.code = core.Code(self.local.target_host, self.local, self.remote)

    def _init_files_dirs(self):
        """Prepare files and directories for the run"""
        self.local.create_files_dirs()
        self.remote.create_files_dirs()

    @staticmethod
    def hosts(source):
        try:
            yield from cdist.hostsource.HostSource(source)()
        except (IOError, OSError, UnicodeError) as e:
            raise cdist.Error(
                    "Error reading hosts from \'{}\': {}".format(
                        source, e))

    @classmethod
    def _check_and_prepare_args(cls, args):
        if args.manifest == '-' and args.hostfile == '-':
            raise cdist.Error(("Cannot read both, manifest and host file, "
                               "from stdin"))

        # if no host source is specified then read hosts from stdin
        if not (args.hostfile or args.host):
            args.hostfile = '-'

        initial_manifest_tempfile = None
        if args.manifest == '-':
            # read initial manifest from stdin
            try:
                handle, initial_manifest_temp_path = tempfile.mkstemp(
                        prefix='cdist.stdin.')
                with os.fdopen(handle, 'w') as fd:
                    fd.write(sys.stdin.read())
            except (IOError, OSError) as e:
                raise cdist.Error(("Creating tempfile for stdin data "
                                   "failed: %s" % e))

            args.manifest = initial_manifest_temp_path
            atexit.register(lambda: os.remove(initial_manifest_temp_path))

        # default remote cmd patterns
        args.remote_exec_pattern = None
        args.remote_copy_pattern = None

        args_dict = vars(args)
        # if remote-exec and/or remote-copy args are None then user
        # didn't specify command line options nor env vars:
        # inspect multiplexing options for default cdist.REMOTE_COPY/EXEC
        if (args_dict['remote_copy'] is None or
                args_dict['remote_exec'] is None):
            mux_opts = inspect_ssh_mux_opts()
            if args_dict['remote_exec'] is None:
                args.remote_exec_pattern = cdist.REMOTE_EXEC + mux_opts
            if args_dict['remote_copy'] is None:
                args.remote_copy_pattern = cdist.REMOTE_COPY + mux_opts

    @classmethod
    def _base_root_path(cls, args):
        if args.out_path:
            base_root_path = args.out_path
        else:
            base_root_path = tempfile.mkdtemp()
        return base_root_path

    @classmethod
    def commandline(cls, args):
        """Configure remote system"""

        # FIXME: Refactor relict - remove later
        log = logging.getLogger("cdist")

        cls._check_and_prepare_args(args)

        process = {}
        failed_hosts = []
        time_start = time.time()

        base_root_path = cls._base_root_path(args)

        hostcnt = 0
        for host in itertools.chain(cls.hosts(args.host),
                                    cls.hosts(args.hostfile)):
            hostdir = cdist.str_hash(host)
            host_base_path = os.path.join(base_root_path, hostdir)

            log.debug("Base root path for target host \"{}\" is \"{}\"".format(
                host, host_base_path))

            hostcnt += 1
            if args.parallel:
                log.debug("Creating child process for %s", host)
                process[host] = multiprocessing.Process(
                        target=cls.onehost,
                        args=(host, host_base_path, hostdir, args, True))
                process[host].start()
            else:
                try:
                    cls.onehost(host, host_base_path, hostdir,
                                args, parallel=False)
                except cdist.Error as e:
                    failed_hosts.append(host)

        # Catch errors in parallel mode when joining
        if args.parallel:
            for host in process.keys():
                log.debug("Joining process %s", host)
                process[host].join()

                if not process[host].exitcode == 0:
                    failed_hosts.append(host)

        time_end = time.time()
        log.info("Total processing time for %s host(s): %s", hostcnt,
                 (time_end - time_start))

        if len(failed_hosts) > 0:
            raise cdist.Error("Failed to configure the following hosts: " +
                              " ".join(failed_hosts))

    @classmethod
    def _resolve_ssh_control_path(cls):
        base_path = tempfile.mkdtemp()
        control_path = os.path.join(base_path, "s")
        atexit.register(lambda: shutil.rmtree(base_path))
        return control_path

    @classmethod
    def _resolve_remote_cmds(cls, args):
        control_path = cls._resolve_ssh_control_path()
        # If we constructed patterns for remote commands then there is
        # placeholder for ssh ControlPath, format it and we have unique
        # ControlPath for each host.
        #
        # If not then use args.remote_exec/copy that user specified.
        if args.remote_exec_pattern:
            remote_exec = args.remote_exec_pattern.format(control_path)
        else:
            remote_exec = args.remote_exec
        if args.remote_copy_pattern:
            remote_copy = args.remote_copy_pattern.format(control_path)
        else:
            remote_copy = args.remote_copy
        return (remote_exec, remote_copy, )

    @classmethod
    def onehost(cls, host, host_base_path, host_dir_name, args, parallel):
        """Configure ONE system"""

        log = logging.getLogger(host)

        try:
            remote_exec, remote_copy = cls._resolve_remote_cmds(args)
            log.debug("remote_exec for host \"{}\": {}".format(
                host, remote_exec))
            log.debug("remote_copy for host \"{}\": {}".format(
                host, remote_copy))

            target_host = ipaddr.resolve_target_addresses(host)
            log.debug("target_host: {}".format(target_host))

            local = cdist.exec.local.Local(
                target_host=target_host,
                base_root_path=host_base_path,
                host_dir_name=host_dir_name,
                initial_manifest=args.manifest,
                add_conf_dirs=args.conf_dir)

            remote = cdist.exec.remote.Remote(
                target_host=target_host,
                remote_exec=remote_exec,
                remote_copy=remote_copy)

            c = cls(local, remote, dry_run=args.dry_run, jobs=args.jobs)
            c.run()

        except cdist.Error as e:
            log.error(e)
            if parallel:
                # We are running in our own process here, need to sys.exit!
                sys.exit(1)
            else:
                raise

        except KeyboardInterrupt:
            # Ignore in parallel mode, we are existing anyway
            if parallel:
                sys.exit(0)
            # Pass back to controlling code in sequential mode
            else:
                raise

    def run(self):
        """Do what is most often done: deploy & cleanup"""
        start_time = time.time()

        self._init_files_dirs()

        self.explorer.run_global_explorers(self.local.global_explorer_out_path)
        self.manifest.run_initial_manifest(self.local.initial_manifest)
        self.iterate_until_finished()

        self.local.save_cache()
        self.log.info("Finished successful run in %s seconds",
                      time.time() - start_time)

    def object_list(self):
        """Short name for object list retrieval"""
        for cdist_object in core.CdistObject.list_objects(
                self.local.object_path, self.local.type_path,
                self.local.object_marker_name):
            if cdist_object.cdist_type.is_install:
                self.log.debug(("Running in config mode, ignoring install "
                                "object: {0}").format(cdist_object))
            else:
                yield cdist_object

    def iterate_once(self):
        """
            Iterate over the objects once - helper method for
            iterate_until_finished
        """
        if self.jobs:
            objects_changed = self._iterate_once_parallel()
        else:
            objects_changed = self._iterate_once_sequential()
        return objects_changed

    def _iterate_once_sequential(self):
        self.log.info("Iteration in sequential mode")
        objects_changed = False

        for cdist_object in self.object_list():
            if cdist_object.requirements_unfinished(cdist_object.requirements):
                """We cannot do anything for this poor object"""
                continue

            if cdist_object.state == core.CdistObject.STATE_UNDEF:
                """Prepare the virgin object"""

                self.object_prepare(cdist_object)
                objects_changed = True

            if cdist_object.requirements_unfinished(cdist_object.autorequire):
                """The previous step created objects we depend on -
                   wait for them
                """
                continue

            if cdist_object.state == core.CdistObject.STATE_PREPARED:
                self.object_run(cdist_object)
                objects_changed = True

        return objects_changed

    def _iterate_once_parallel(self):
        self.log.info("Iteration in parallel mode in {} jobs".format(
            self.jobs))
        objects_changed = False

        cargo = []
        for cdist_object in self.object_list():
            if cdist_object.requirements_unfinished(cdist_object.requirements):
                """We cannot do anything for this poor object"""
                continue

            if cdist_object.state == core.CdistObject.STATE_UNDEF:
                """Prepare the virgin object"""

                # self.object_prepare(cdist_object)
                # objects_changed = True
                cargo.append(cdist_object)

        n = len(cargo)
        if n == 1:
            self.log.debug("Only one object, preparing sequentially")
            self.object_prepare(cargo[0])
            objects_changed = True
        elif cargo:
            self.log.debug("Multiprocessing start method is {}".format(
                multiprocessing.get_start_method()))
            self.log.debug(("Starting multiprocessing Pool for {} parallel "
                            "objects preparation".format(n)))
            args = [
                (c, ) for c in cargo
            ]
            mp_pool_run(self.object_prepare, args, jobs=self.jobs)
            self.log.debug(("Multiprocessing for parallel object "
                            "preparation finished"))
            objects_changed = True

        del cargo[:]
        for cdist_object in self.object_list():
            if cdist_object.requirements_unfinished(cdist_object.requirements):
                """We cannot do anything for this poor object"""
                continue

            if cdist_object.state == core.CdistObject.STATE_PREPARED:
                if cdist_object.requirements_unfinished(
                        cdist_object.autorequire):
                    """The previous step created objects we depend on -
                    wait for them
                    """
                    continue

                # self.object_run(cdist_object)
                # objects_changed = True
                cargo.append(cdist_object)

        n = len(cargo)
        if n == 1:
            self.log.debug("Only one object, running sequentially")
            self.object_run(cargo[0])
            objects_changed = True
        elif cargo:
            self.log.debug("Multiprocessing start method is {}".format(
                multiprocessing.get_start_method()))
            self.log.debug(("Starting multiprocessing Pool for {} parallel "
                            "object run".format(n)))
            args = [
                (c, ) for c in cargo
            ]
            mp_pool_run(self.object_run, args, jobs=self.jobs)
            self.log.debug(("Multiprocessing for parallel object "
                            "run finished"))
            objects_changed = True

        return objects_changed

    def _open_logger(self):
        self.log = logging.getLogger(self.local.target_host[0])

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

    def iterate_until_finished(self):
        """
            Go through all objects and solve them
            one after another
        """

        objects_changed = True

        while objects_changed:
            objects_changed = self.iterate_once()

        # Check whether all objects have been finished
        unfinished_objects = []
        for cdist_object in self.object_list():
            if not cdist_object.state == cdist_object.STATE_DONE:
                unfinished_objects.append(cdist_object)

        if unfinished_objects:
            info_string = []

            for cdist_object in unfinished_objects:

                requirement_names = []
                autorequire_names = []

                for requirement in cdist_object.requirements_unfinished(
                        cdist_object.requirements):
                    requirement_names.append(requirement.name)

                for requirement in cdist_object.requirements_unfinished(
                        cdist_object.autorequire):
                    autorequire_names.append(requirement.name)

                requirements = "\n        ".join(requirement_names)
                autorequire = "\n        ".join(autorequire_names)
                info_string.append(("%s requires:\n"
                                    "        %s\n"
                                    "%s ""autorequires:\n"
                                    "        %s" % (
                                        cdist_object.name,
                                        requirements, cdist_object.name,
                                        autorequire)))

            raise cdist.UnresolvableRequirementsError(
                    ("The requirements of the following objects could not be "
                     "resolved:\n%s") % ("\n".join(info_string)))

    def object_prepare(self, cdist_object):
        """Prepare object: Run type explorer + manifest"""
        self.log.info(
                "Running manifest and explorers for " + cdist_object.name)
        self.explorer.run_type_explorers(cdist_object)
        self.manifest.run_type_manifest(cdist_object)
        cdist_object.state = core.CdistObject.STATE_PREPARED

    def object_run(self, cdist_object):
        """Run gencode and code for an object"""

        self.log.debug("Trying to run object %s" % (cdist_object.name))
        if cdist_object.state == core.CdistObject.STATE_DONE:
            raise cdist.Error(("Attempting to run an already finished "
                               "object: %s"), cdist_object)

        cdist_type = cdist_object.cdist_type

        # Generate
        self.log.info("Generating code for %s" % (cdist_object.name))
        cdist_object.code_local = self.code.run_gencode_local(cdist_object)
        cdist_object.code_remote = self.code.run_gencode_remote(cdist_object)
        if cdist_object.code_local or cdist_object.code_remote:
            cdist_object.changed = True

        # Execute
        if not self.dry_run:
            if cdist_object.code_local or cdist_object.code_remote:
                self.log.info("Executing code for %s" % (cdist_object.name))
            if cdist_object.code_local:
                self.code.run_code_local(cdist_object)
            if cdist_object.code_remote:
                self.code.transfer_code_remote(cdist_object)
                self.code.run_code_remote(cdist_object)
        else:
            self.log.info("Skipping code execution due to DRY RUN")

        # Mark this object as done
        self.log.debug("Finishing run of " + cdist_object.name)
        cdist_object.state = core.CdistObject.STATE_DONE
