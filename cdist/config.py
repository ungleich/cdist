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
import shutil
import sys
import time
import pprint
import itertools
import tempfile
import socket

import cdist

import cdist.exec.local
import cdist.exec.remote

from cdist import core


def inspect_ssh_mux_opts():
    """Inspect whether or not ssh supports multiplexing options.

       Return string containing multiplexing options if supported.
       If ControlPath is supported then placeholder for that path is
       specified and can be used for final string formatting.
       For example, this function can return string:
       "-o ControlMaster=auto -o ControlPersist=125 -o ControlPath={}".
       Then it can be formatted:
       mux_opts_string.format('/tmp/tmpxxxxxx/ssh-control-path').
    """
    import subprocess

    wanted_mux_opts = {
        "ControlPath": "{}",
        "ControlMaster": "auto",
        "ControlPersist": "125",
    }
    mux_opts = " ".join([" -o {}={}".format(
        x, wanted_mux_opts[x]) for x in wanted_mux_opts])
    try:
        subprocess.check_output("ssh {}".format(mux_opts),
                                stderr=subprocess.STDOUT, shell=True)
    except subprocess.CalledProcessError as e:
        subproc_output = e.output.decode().lower()
        if "bad configuration option" in subproc_output:
            return ""
    return mux_opts


class Config(object):
    """Cdist main class to hold arbitrary data"""

    def __init__(self, local, remote, dry_run=False, jobs=None):

        self.local = local
        self.remote = remote
        self.log = logging.getLogger(self.local.target_host[0])
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
    def hostfile_process_line(line):
        """Return host from read line or None if no host present."""
        if not line:
            return None
        # remove comment if present
        comment_index = line.find('#')
        if comment_index >= 0:
            host = line[:comment_index]
        else:
            host = line
        # remove leading and trailing whitespaces
        host = host.strip()
        # skip empty lines
        if host:
            return host
        else:
            return None

    @staticmethod
    def hosts(source):
        """Yield hosts from source.
           Source can be a sequence or filename (stdin if \'-\').
           In case of filename each line represents one host.
        """
        if isinstance(source, str):
            import fileinput
            try:
                for host in fileinput.input(files=(source)):
                    host = Config.hostfile_process_line(host)
                    if host:
                        yield host
            except (IOError, OSError, UnicodeError) as e:
                raise cdist.Error(
                        "Error reading hosts from file \'{}\': {}".format(
                            source, e))
        else:
            if source:
                for host in source:
                    yield host

    @classmethod
    def commandline(cls, args):
        """Configure remote system"""
        import multiprocessing

        # FIXME: Refactor relict - remove later
        log = logging.getLogger("cdist")

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
            import atexit
            atexit.register(lambda: os.remove(initial_manifest_temp_path))

        process = {}
        failed_hosts = []
        time_start = time.time()

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

        if args.out_path:
            base_root_path = args.out_path
        else:
            base_root_path = tempfile.mkdtemp()

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
    def onehost(cls, host, host_base_path, host_dir_name, args, parallel):
        """Configure ONE system"""

        log = logging.getLogger(host)

        try:
            control_path = os.path.join(host_base_path, "ssh-control-path")
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
            log.debug("remote_exec for host \"{}\": {}".format(
                host, remote_exec))
            log.debug("remote_copy for host \"{}\": {}".format(
                host, remote_copy))

            try:
                # getaddrinfo returns a list of 5-tuples:
                # (family, type, proto, canonname, sockaddr)
                # where sockaddr is:
                # (address, port) for AF_INET,
                # (address, port, flow_info, scopeid) for AF_INET6
                ip_addr = socket.getaddrinfo(
                        host, None, type=socket.SOCK_STREAM)[0][4][0]
                # gethostbyaddr returns triple
                # (hostname, aliaslist, ipaddrlist)
                host_name = socket.gethostbyaddr(ip_addr)[0]
                log.debug("derived host_name for host \"{}\": {}".format(
                    host, host_name))
            except (socket.gaierror, socket.herror) as e:
                log.warn("Could not derive host_name for {}"
                         ", $host_name will be empty. Error is: {}".format(
                             host, e))
                # in case of error provide empty value
                host_name = ''

            try:
                host_fqdn = socket.getfqdn(host)
                log.debug("derived host_fqdn for host \"{}\": {}".format(
                    host, host_fqdn))
            except socket.herror as e:
                log.warn("Could not derive host_fqdn for {}"
                         ", $host_fqdn will be empty. Error is: {}".format(
                             host, e))
                # in case of error provide empty value
                host_fqdn = ''

            target_host = (host, host_name, host_fqdn)

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
