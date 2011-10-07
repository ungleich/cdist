#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2010-2011 Nico Schottelius (nico-cdist at schottelius.org)
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
import stat
import sys

import cdist.context
import cdist.core
import cdist.emulator

log = logging.getLogger(__name__)

CODE_HEADER = "#!/bin/sh -e\n"

class ConfigInstall:
    """Cdist main class to hold arbitrary data"""

    def __init__(self, target_host, initial_manifest=False,
        base_path=False,
        exec_path=sys.argv[0],
        debug=False):

        self.target_host    = target_host
        os.environ['target_host'] = target_host

        self.debug          = debug
        self.exec_path      = exec_path

        self.context = cdist.context.Context(self.target_host,
            initial_manifest=initial_manifest,
            base_path=base_path,
            debug=debug)

    def cleanup(self):
        self.path.cleanup()

    def run_initial_manifest(self):
        """Run the initial manifest"""
        log.info("Running initial manifest %s", self.context.initial_manifest)
        env = {  "__manifest" : self.context.manifest_path }
        self.run_manifest(self.context.initial_manifest, extra_env=env)

    def run_type_manifest(self, cdist_object):
        """Run manifest for a specific object"""
        type = cdist_object.type
        manifest_path = os.path.join(self.context.type_base_path,
                            type.manifest_path)
        
        log.debug("%s: Running %s", cdist_object.name, manifest)
        if os.path.exists(manifest_path):
            env = { "__object" :    os.path.join(self.context.object_base_path,
                                        cdist_object.path),
                    "__object_id":  cdist_object.object_id,
                    "__object_fq":  cdist_object.name,
                    "__type":       os.path.join(self.context.type_base_path,
                                        type.path)
                    }
            self.run_manifest(manifest_path, extra_env=env)

    def run_manifest(self, manifest_path, extra_env=None):
        """Run a manifest"""
        log.debug("Running manifest %s, env=%s", manifest_path, extra_env)
        env = os.environ.copy()
        env['PATH'] = self.context.bin_path + ":" + env['PATH']

        # Information required in every manifest
        env['__target_host']            = self.target_host
        env['__global']                 = self.context.out_path
        
        # Submit debug flag to manifest, can be used by emulator and types
        if self.debug:
            env['__debug']                  = "yes"

        # Required for recording source in emulator
        env['__cdist_manifest']         = manifest_path

        # Required to find types in emulator
        env['__cdist_type_base_path']    = type.path

        # Other environment stuff
        if extra_env:
            env.update(extra_env)

        cdist.exec.shell_run_or_debug_fail(manifest_path, [manifest_path], env=env)

    def object_run(self, cdist_object):
        """Run gencode or code for an object"""
        log.debug("Running object %s", cdist_object)

        # Catch requirements, which re-call us
        if cdist_object.ran:
            return

        type = cdist_object.type
            
        for requirement in cdist_object.requirements:
            log.debug("Object %s requires %s", cdist_object, requirement)
            self.object_run(requirement)

        #
        # Setup env Variable:
        #
        env = os.environ.copy()
        env['__target_host']    = self.target_host
        env['__global']         = self.context.out_path
        env["__object"]         = os.path.join(self.context.object_base_path, cdist_object.path)
        env["__object_id"]      = cdist_object.object_id
        env["__object_fq"]      = cdist_object.name
        env["__type"]           = type.name

        # gencode
        for cmd in ["local", "remote"]:
            bin = os.path.join(self.context.type_base_path,
                    getattr(type, "gencode_" + cmd))

            if os.path.isfile(bin):
                outfile = os.path.join(self.context.object_base_path,
                            getattr(cdist_object, "code_" + cmd))

                outfile_fd = open(outfile, "w")

                # Need to flush to ensure our write is done before stdout write
                outfile_fd.write(CODE_HEADER)
                outfile_fd.flush()

                cdist.exec.shell_run_or_debug_fail(bin, [bin], env=env, stdout=outfile_fd)
                outfile_fd.close()

                status = os.stat(outfile)

                # Remove output if empty, else make it executable
                if status.st_size == len(CODE_HEADER):
                    os.unlink(outfile)
                else:
                    # Add header and make executable - identically to 0o700
                    os.chmod(outfile, stat.S_IXUSR | stat.S_IRUSR | stat.S_IWUSR)
                    cdist_object.changed=True

        # code local
        code_local = cdist_object.code_local_path
        if os.path.isfile(code_local):
            cdist.exec.run_or_fail([code_local])

        # code remote
        local_remote_code   = cdist_object.code_remote_path
        remote_remote_code  = cdist_object.remote_code_remote_path
        if os.path.isfile(local_remote_code):
            self.context.transfer_file(local_remote_code, remote_remote_code)
            cdist.exec.run_or_fail([remote_remote_code], remote_prefix=True)

        cdist_object.ran = True

    def run_type_explorer(self, cdist_object):
        """Run type specific explorers for objects"""

        type = cdist_object.type
        self.transfer_type_explorers(type)

        cmd = []
        cmd.append("__explorer="        + self.context.remote_global_explorer_path)
        cmd.append("__type_explorer="   + type.explorer_remote_path)
        cmd.append("__object="          + object.path_remote)
        cmd.append("__object_id="       + object.object_id)
        cmd.append("__object_fq="       + cdist_object)

        # Need to transfer at least the parameters for objects to be useful
        self.path.transfer_object_parameter(cdist_object)

        explorers = self.path.list_type_explorers(type)
        for explorer in explorers:
            remote_cmd = cmd + [os.path.join(type.explorer_remote_path, explorer)]
            output = os.path.join(cdist_object.explorer_output_path(), explorer)
            output_fd = open(output, mode='w')
            log.debug("%s exploring %s using %s storing to %s", 
                            cdist_object, explorer, remote_cmd, output)
                        
            cdist.exec.run_or_fail(remote_cmd, stdout=output_fd, remote_prefix=True)
            output_fd.close()


    def link_emulator(self):
        """Link emulator to types"""
        src = os.path.abspath(self.exec_path)
        for type in cdist.core.Type.list_types(self.context.type_base_path):
            dst = os.path.join(self.context.bin_path, type.name)
            log.debug("Linking emulator: %s to %s", src, dst)

            # FIXME: handle exception / make it more beautiful
            os.symlink(src, dst)

    def run_global_explorers(self):
        """Run global explorers"""
        log.info("Running global explorers")

        src_path = self.context.global_explorer_path
        dst_path = self.context.global_explorer_out_path
        remote_dst_path = self.context.remote_global_explorer_path

        self.context.transfer_path(src_path, remote_dst_path)

        for explorer in os.listdir(src_path):
            output_fd = open(os.path.join(dst_path, explorer), mode='w')
            cmd = []
            cmd.append("__explorer=" + remote_dst_path)
            cmd.append(os.path.join(src_path, explorer))

            cdist.exec.run_or_fail(cmd, stdout=output_fd, remote_prefix=True)
            output_fd.close()


    def stage_run(self):
        """The final (and real) step of deployment"""
        log.info("Generating and executing code")
        for cdist_object in cdist.core.Object.list_objects():
            log.debug("Run object: %s", cdist_object)
            self.object_run(cdist_object)

    def deploy_to(self):
        """Mimic the old deploy to: Deploy to one host"""
        log.info("Deploying to " + self.target_host)
        self.stage_prepare()
        self.stage_run()

    def deploy_and_cleanup(self):
        """Do what is most often done: deploy & cleanup"""
        self.deploy_to()
        self.cleanup()

####FIXED ######################################################################

    def stage_prepare(self):
        """Do everything for a deploy, minus the actual code stage"""
        self.link_emulator()
        self.run_global_explorers()
        self.run_initial_manifest()
        
        log.info("Running object manifests and type explorers")
        log.debug("Searching for objects in " + cdist.core.Object.base_path())

        # Continue process until no new objects are created anymore
        new_objects_created = True
        while new_objects_created:
            new_objects_created = False
            for cdist_object in cdist.core.Object.list_objects():
                if cdist_object.prepared:
                    log.debug("Skipping rerun of object %s", cdist_object)
                    continue
                else:
                    log.debug("Preparing object: " + cdist_object.name)
                    self.run_type_explorer(cdist_object)
                    self.run_type_manifest(cdist_object)
                    cdist_object.prepared = True
                    new_objects_created = True

    def transfer_object_parameter(self, cdist_object):
        """Transfer the object parameter to the remote destination"""
        src  = os.path.join(self.context.object_base_path,
            cdist_object.parameter_path)
        dst = os.path.join(self.context.remote_object_path,
            cdist_object.parameter_path)

        # Synchronise parameter dir afterwards
        self.transfer_path(local_path, remote_path)

    def transfer_global_explorers(self):
        """Transfer the global explorers"""
        self.remote_mkdir(self.context.remote_global_explorer_path)
        self.transfer_path(self.context.global_explorer_path, 
            self.remote_global_explorer_path)

    def transfer_type_explorers(self, type):
        """Transfer explorers of a type, but only once"""
        if type.transferred_explorers:
            log.debug("Skipping retransfer for explorers of %s", type)
            return
        else:
            # Do not retransfer
            type.transferred_explorers = True

        explorers = type.explorers()

        if len(explorers) > 0:
            rel_path = os.path.join(type.explorer_path(), explorer)
            src = os.path.join(self.context.type_base_path, rel_path)
            dst = os.path.join(self.context.remote_type_path, rel_path)

            # Ensure that the path exists
            self.remote_mkdir(dst)
            self.transfer_path(src, dst)
