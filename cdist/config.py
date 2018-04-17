#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2010-2015 Nico Schottelius (nico-cdist at schottelius.org)
# 2013-2017 Steven Armstrong (steven-cdist at armstrong.cc)
# 2016-2017 Darko Poljak (darko.poljak at gmail.com)
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
import multiprocessing
from cdist.mputil import mp_pool_run, mp_sig_handler
import atexit
import shutil
import socket
import cdist
import cdist.hostsource
import cdist.exec.local
import cdist.exec.remote
import cdist.util.ipaddr as ipaddr
import cdist.configuration
from cdist import core, inventory
from cdist.util.remoteutil import inspect_ssh_mux_opts


class Config(object):
    """Cdist main class to hold arbitrary data"""

    # list of paths (files and/or directories) that will be removed on finish
    _paths_for_removal = []

    @classmethod
    def _register_path_for_removal(cls, path):
        cls._paths_for_removal.append(path)

    @classmethod
    def _remove_paths(cls):
        while cls._paths_for_removal:
            path = cls._paths_for_removal.pop()
            if os.path.isfile(path):
                os.remove(path)
            else:
                shutil.rmtree(path)

    def __init__(self, local, remote, dry_run=False, jobs=None,
                 cleanup_cmds=None, remove_remote_files_dirs=False):

        self.local = local
        self.remote = remote
        self._open_logger()
        self.dry_run = dry_run
        self.jobs = jobs
        if cleanup_cmds:
            self.cleanup_cmds = cleanup_cmds
        else:
            self.cleanup_cmds = []
        self.remove_remote_files_dirs = remove_remote_files_dirs

        self.explorer = core.Explorer(self.local.target_host, self.local,
                                      self.remote, jobs=self.jobs)
        self.manifest = core.Manifest(self.local.target_host, self.local)
        self.code = core.Code(self.local.target_host, self.local, self.remote)

    def _init_files_dirs(self):
        """Prepare files and directories for the run"""
        self.local.create_files_dirs()
        self.remote.create_files_dirs()

    def _remove_remote_files_dirs(self):
        """Remove remote files and directories for the run"""
        self.remote.remove_files_dirs()

    def _remove_files_dirs(self):
        """Remove files and directories for the run"""
        if self.remove_remote_files_dirs:
            self._remove_remote_files_dirs()

    @staticmethod
    def hosts(source):
        try:
            yield from cdist.hostsource.HostSource(source)()
        except (IOError, OSError, UnicodeError) as e:
            raise cdist.Error(
                    "Error reading hosts from \'{}\': {}".format(
                        source, e))

    @staticmethod
    def construct_remote_exec_copy_patterns(args):
        # default remote cmd patterns
        args.remote_cmds_cleanup_pattern = ""
        args.remote_exec_pattern = None
        args.remote_copy_pattern = None

        # Determine forcing IPv4/IPv6 options if any, only for
        # default remote commands.
        if args.force_ipv:
            force_addr_opt = " -{}".format(args.force_ipv)
        else:
            force_addr_opt = ""

        args_dict = vars(args)
        # if remote-exec and/or remote-copy args are None then user
        # didn't specify command line options nor env vars:
        # inspect multiplexing options for default cdist.REMOTE_COPY/EXEC
        if (args_dict['remote_copy'] is None or
                args_dict['remote_exec'] is None):
            mux_opts = inspect_ssh_mux_opts()
            if args_dict['remote_exec'] is None:
                args.remote_exec_pattern = (cdist.REMOTE_EXEC +
                                            force_addr_opt + mux_opts)
            if args_dict['remote_copy'] is None:
                args.remote_copy_pattern = (cdist.REMOTE_COPY +
                                            force_addr_opt + mux_opts)
            if mux_opts:
                cleanup_pattern = cdist.REMOTE_CMDS_CLEANUP_PATTERN
            else:
                cleanup_pattern = ""
            args.remote_cmds_cleanup_pattern = cleanup_pattern

    @classmethod
    def _check_and_prepare_args(cls, args):
        if args.manifest == '-' and args.hostfile == '-':
            raise cdist.Error(("Cannot read both, manifest and host file, "
                               "from stdin"))

        # if no host source is specified then read hosts from stdin
        if not (args.hostfile or args.host):
            args.hostfile = '-'

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

    @classmethod
    def commandline(cls, args):
        """Configure remote system"""

        # FIXME: Refactor relict - remove later
        log = logging.getLogger("cdist")

        # No new child process if only one host at a time.
        if args.parallel == 1:
            log.debug("Only 1 parallel process, doing it sequentially")
            args.parallel = 0

        if args.parallel or args.jobs:
            # If parallel execution then also log process id
            cdist.log.setupParallelLogging()
            log = logging.getLogger("cdist")

        if args.parallel:
            import signal

            signal.signal(signal.SIGTERM, mp_sig_handler)
            signal.signal(signal.SIGHUP, mp_sig_handler)

        cls._check_and_prepare_args(args)

        failed_hosts = []
        time_start = time.time()

        cls.construct_remote_exec_copy_patterns(args)
        base_root_path = cls.create_base_root_path(args.out_path)

        hostcnt = 0

        cfg = cdist.configuration.Configuration(args)
        configuration = cfg.get_config(section='GLOBAL')

        if args.tag or args.all_tagged_hosts:
            inventory.determine_default_inventory_dir(args, configuration)
            if args.all_tagged_hosts:
                inv_list = inventory.InventoryList(
                    hosts=None, istag=True, hostfile=None,
                    db_basedir=args.inventory_dir)
            else:
                inv_list = inventory.InventoryList(
                    hosts=args.host, istag=True, hostfile=args.hostfile,
                    db_basedir=args.inventory_dir,
                    has_all_tags=args.has_all_tags)
            it = inv_list.entries()
        else:
            it = itertools.chain(cls.hosts(args.host),
                                 cls.hosts(args.hostfile))

        process_args = []
        if args.parallel:
            log.trace("Processing hosts in parallel")
        else:
            log.trace("Processing hosts sequentially")
        for entry in it:
            if isinstance(entry, tuple):
                # if configuring by specified tags
                host = entry[0]
                host_tags = entry[1]
            else:
                # if configuring by host then check inventory for tags
                host = entry
                inventory.determine_default_inventory_dir(args, configuration)
                inv_list = inventory.InventoryList(
                    hosts=(host,), db_basedir=args.inventory_dir)
                inv = tuple(inv_list.entries())
                if inv:
                    # host is present in inventory and has tags
                    host_tags = inv[0][1]
                else:
                    # host is not present in inventory or has no tags
                    host_tags = None
            host_base_path, hostdir = cls.create_host_base_dirs(
                host, base_root_path)
            log.debug("Base root path for target host \"{}\" is \"{}\"".format(
                host, host_base_path))

            hostcnt += 1
            if args.parallel:
                pargs = (host, host_tags, host_base_path, hostdir, args, True,
                         configuration)
                log.trace(("Args for multiprocessing operation "
                           "for host {}: {}".format(host, pargs)))
                process_args.append(pargs)
            else:
                try:
                    cls.onehost(host, host_tags, host_base_path, hostdir,
                                args, parallel=False,
                                configuration=configuration)
                except cdist.Error as e:
                    failed_hosts.append(host)
        if args.parallel and len(process_args) == 1:
            log.debug("Only 1 host for parallel processing, doing it "
                      "sequentially")
            try:
                cls.onehost(*process_args[0])
            except cdist.Error as e:
                failed_hosts.append(host)
        elif args.parallel:
            log.trace("Multiprocessing start method is {}".format(
                multiprocessing.get_start_method()))
            log.trace(("Starting multiprocessing Pool for {} "
                       "parallel host operation".format(args.parallel)))

            results = mp_pool_run(cls.onehost,
                                  process_args,
                                  jobs=args.parallel)
            log.trace(("Multiprocessing for parallel host operation "
                       "finished"))
            log.trace("Multiprocessing for parallel host operation "
                      "results: %s", results)

            failed_hosts = [host for host, result in results if not result]

        time_end = time.time()
        log.verbose("Total processing time for %s host(s): %s", hostcnt,
                    (time_end - time_start))

        if len(failed_hosts) > 0:
            raise cdist.Error("Failed to configure the following hosts: " +
                              " ".join(failed_hosts))
        elif not args.out_path:
            # If tmp out path created then remove it, but only if no failed
            # hosts.
            shutil.rmtree(base_root_path)

    @classmethod
    def _resolve_ssh_control_path(cls):
        base_path = tempfile.mkdtemp()
        cls._register_path_for_removal(base_path)
        control_path = os.path.join(base_path, "s")
        return control_path

    @classmethod
    def _resolve_remote_cmds(cls, args):
        if (args.remote_exec_pattern or
                args.remote_copy_pattern or
                args.remote_cmds_cleanup_pattern):
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
        if args.remote_cmds_cleanup_pattern:
            remote_cmds_cleanup = args.remote_cmds_cleanup_pattern.format(
                control_path)
        else:
            remote_cmds_cleanup = ""
        return (remote_exec, remote_copy, remote_cmds_cleanup, )

    @staticmethod
    def _address_family(args):
        if args.force_ipv == 4:
            family = socket.AF_INET
        elif args.force_ipv == 6:
            family = socket.AF_INET6
        else:
            family = 0
        return family

    @staticmethod
    def resolve_target_addresses(host, family):
        try:
            return ipaddr.resolve_target_addresses(host, family)
        except:
            e = sys.exc_info()[1]
            raise cdist.Error(("Error resolving target addresses for host '{}'"
                               ": {}").format(host, e))

    @classmethod
    def onehost(cls, host, host_tags, host_base_path, host_dir_name, args,
                parallel, configuration, remove_remote_files_dirs=False):
        """Configure ONE system.
           If operating in parallel then return tuple (host, True|False, )
           so that main process knows for which host function was successful.
        """

        log = logging.getLogger(host)

        try:
            remote_exec, remote_copy, cleanup_cmd = cls._resolve_remote_cmds(
                args)
            log.debug("remote_exec for host \"{}\": {}".format(
                host, remote_exec))
            log.debug("remote_copy for host \"{}\": {}".format(
                host, remote_copy))

            family = cls._address_family(args)
            log.debug("address family: {}".format(family))
            target_host = cls.resolve_target_addresses(host, family)
            log.debug("target_host for host \"{}\": {}".format(
                host, target_host))

            local = cdist.exec.local.Local(
                target_host=target_host,
                target_host_tags=host_tags,
                base_root_path=host_base_path,
                host_dir_name=host_dir_name,
                initial_manifest=args.manifest,
                add_conf_dirs=args.conf_dir,
                cache_path_pattern=args.cache_path_pattern,
                quiet_mode=args.quiet,
                configuration=configuration,
                exec_path=sys.argv[0],
                save_output_streams=args.save_output_streams)

            remote = cdist.exec.remote.Remote(
                target_host=target_host,
                remote_exec=remote_exec,
                remote_copy=remote_copy,
                base_path=args.remote_out_path,
                quiet_mode=args.quiet,
                archiving_mode=args.use_archiving,
                configuration=configuration,
                stdout_base_path=local.stdout_base_path,
                stderr_base_path=local.stderr_base_path,
                save_output_streams=args.save_output_streams)

            cleanup_cmds = []
            if cleanup_cmd:
                cleanup_cmds.append(cleanup_cmd)
            c = cls(local, remote, dry_run=args.dry_run, jobs=args.jobs,
                    cleanup_cmds=cleanup_cmds,
                    remove_remote_files_dirs=remove_remote_files_dirs)
            c.run()
            cls._remove_paths()

        except cdist.Error as e:
            log.error(e)
            if parallel:
                return (host, False, )
            else:
                raise

        if parallel:
            return (host, True, )

    @staticmethod
    def create_base_root_path(out_path=None):
        if out_path:
            base_root_path = out_path
        else:
            base_root_path = tempfile.mkdtemp()

        return base_root_path

    @staticmethod
    def create_host_base_dirs(host, base_root_path):
        hostdir = cdist.str_hash(host)
        host_base_path = os.path.join(base_root_path, hostdir)

        return (host_base_path, hostdir)

    def run(self):
        """Do what is most often done: deploy & cleanup"""
        start_time = time.time()

        self.log.info("Starting {} run".format(
            'dry' if self.dry_run else 'configuration'))

        self._init_files_dirs()

        self.explorer.run_global_explorers(self.local.global_explorer_out_path)
        try:
            self.manifest.run_initial_manifest(self.local.initial_manifest)
        except cdist.Error as e:
            which = "init"
            stdout_path = os.path.join(self.local.stdout_base_path, which)
            stderr_path = os.path.join(self.local.stderr_base_path, which)
            raise cdist.InitialManifestError(self.local.initial_manifest,
                                             stdout_path, stderr_path, e)
        self.iterate_until_finished()
        self.cleanup()
        self._remove_files_dirs()

        self.local.save_cache(start_time)
        self.log.info("Finished {} run in {:.2f} seconds".format(
                      'dry' if self.dry_run else 'successful',
                      time.time() - start_time))

    def cleanup(self):
        self.log.debug("Running cleanup commands")
        for cleanup_cmd in self.cleanup_cmds:
            cmd = cleanup_cmd.split()
            cmd.append(self.local.target_host[0])
            try:
                if self.log.getEffectiveLevel() <= logging.DEBUG:
                    quiet_mode = False
                else:
                    quiet_mode = True
                self.local.run(cmd, return_output=False, save_output=False,
                               quiet_mode=quiet_mode)
            except cdist.Error as e:
                # Log warning but continue.
                self.log.warning("Cleanup command failed: %s", e)

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
        self.log.debug("Iteration in sequential mode")
        objects_changed = False

        for cdist_object in self.object_list():
            if cdist_object.requirements_unfinished(
                    cdist_object.requirements):
                """We cannot do anything for this poor object"""
                continue

            if cdist_object.state == core.CdistObject.STATE_UNDEF:
                """Prepare the virgin object"""

                self.object_prepare(cdist_object)
                objects_changed = True

            if cdist_object.requirements_unfinished(
                    cdist_object.autorequire):
                """The previous step created objects we depend on -
                    wait for them
                """
                continue

            if cdist_object.state == core.CdistObject.STATE_PREPARED:
                self.object_run(cdist_object)
                objects_changed = True

        return objects_changed

    def _iterate_once_parallel(self):
        self.log.debug("Iteration in parallel mode in {} jobs".format(
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
            self.log.trace("Multiprocessing start method is {}".format(
                multiprocessing.get_start_method()))

            self.log.trace("Multiprocessing cargo: %s", cargo)

            cargo_types = set()
            for c in cargo:
                cargo_types.add(c.cdist_type)
            self.log.trace("Multiprocessing cargo_types: %s", cargo_types)
            nt = len(cargo_types)
            if nt == 1:
                self.log.debug(("Only one type, transfering explorers "
                                "sequentially"))
                self.explorer.transfer_type_explorers(cargo_types.pop())
            else:
                self.log.trace(("Starting multiprocessing Pool for {} "
                                "parallel transfering types' explorers".format(
                                    nt)))
                args = [
                    (ct, ) for ct in cargo_types
                ]
                mp_pool_run(self.explorer.transfer_type_explorers, args,
                            jobs=self.jobs)
                self.log.trace(("Multiprocessing for parallel transfering "
                                "types' explorers finished"))

            self.log.trace(("Starting multiprocessing Pool for {} parallel "
                            "objects preparation".format(n)))
            args = [
                (c, False, ) for c in cargo
            ]
            mp_pool_run(self.object_prepare, args, jobs=self.jobs)
            self.log.trace(("Multiprocessing for parallel object "
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

                # put objects in chuncks of distinct types
                # so that there is no more than one object
                # of the same type in one chunk because there is a
                # possibility of object's process locking which
                # prevents parallel execution at remote
                # and do this only for nonparallel marked types
                for chunk in cargo:
                    for obj in chunk:
                        if (obj.cdist_type == cdist_object.cdist_type and
                           cdist_object.cdist_type.is_nonparallel):
                            break
                    else:
                        chunk.append(cdist_object)
                        break
                else:
                    chunk = [cdist_object, ]
                    cargo.append(chunk)

        for chunk in cargo:
            self.log.trace("Running chunk: %s", chunk)
            n = len(chunk)
            if n == 1:
                self.log.debug("Only one object, running sequentially")
                self.object_run(chunk[0])
                objects_changed = True
            elif chunk:
                self.log.trace("Multiprocessing start method is {}".format(
                    multiprocessing.get_start_method()))
                self.log.trace(("Starting multiprocessing Pool for {} "
                               "parallel object run".format(n)))
                args = [
                    (c, ) for c in chunk
                ]
                mp_pool_run(self.object_run, args, jobs=self.jobs)
                self.log.trace(("Multiprocessing for parallel object "
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

    def object_prepare(self, cdist_object, transfer_type_explorers=True):
        """Prepare object: Run type explorer + manifest"""
        try:
            self.log.verbose("Preparing object {}".format(cdist_object.name))
            self.log.verbose(
                    "Running manifest and explorers for " + cdist_object.name)
            self.explorer.run_type_explorers(cdist_object,
                                             transfer_type_explorers)
            self.manifest.run_type_manifest(cdist_object)
            cdist_object.state = core.CdistObject.STATE_PREPARED
        except cdist.Error as e:
            raise cdist.CdistObjectError(cdist_object, e)

    def object_run(self, cdist_object):
        """Run gencode and code for an object"""
        try:
            self.log.verbose("Running object " + cdist_object.name)
            if cdist_object.state == core.CdistObject.STATE_DONE:
                raise cdist.Error(("Attempting to run an already finished "
                                   "object: %s"), cdist_object)

            # Generate
            self.log.debug("Generating code for %s" % (cdist_object.name))
            cdist_object.code_local = self.code.run_gencode_local(cdist_object)
            cdist_object.code_remote = self.code.run_gencode_remote(
                cdist_object)
            if cdist_object.code_local or cdist_object.code_remote:
                cdist_object.changed = True

            # Execute
            if cdist_object.code_local or cdist_object.code_remote:
                self.log.info("Processing %s" % (cdist_object.name))
            if not self.dry_run:
                if cdist_object.code_local:
                    self.log.trace("Executing local code for %s"
                                   % (cdist_object.name))
                    self.code.run_code_local(cdist_object)
                if cdist_object.code_remote:
                    self.log.trace("Executing remote code for %s"
                                   % (cdist_object.name))
                    self.code.transfer_code_remote(cdist_object)
                    self.code.run_code_remote(cdist_object)

            # Mark this object as done
            self.log.trace("Finishing run of " + cdist_object.name)
            cdist_object.state = core.CdistObject.STATE_DONE
        except cdist.Error as e:
            raise cdist.CdistObjectError(cdist_object, e)
