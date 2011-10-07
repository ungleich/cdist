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

import cdist.emulator
import cdist.path

import cdist.core

log = logging.getLogger(__name__)

CODE_HEADER = "#!/bin/sh -e\n"

class ConfigInstall:
    """Cdist main class to hold arbitrary data"""

    def __init__(self, target_host, initial_manifest=False,
                    exec_path=sys.argv[0],
                    debug=False):

        self.target_host    = target_host
        os.environ['target_host'] = target_host

        self.debug          = debug
        self.exec_path      = exec_path

        self.path = cdist.path.Path(self.target_host, 
                        initial_manifest=initial_manifest,
                        debug=debug)
        
    def cleanup(self):
        self.path.cleanup()



    def run_initial_manifest(self):
        """Run the initial manifest"""
        log.info("Running initial manifest %s", self.path.initial_manifest)
        env = {  "__manifest" : self.path.manifest_dir }
        self.run_manifest(self.path.initial_manifest, extra_env=env)

    def run_type_manifest(self, cdist_object):
        """Run manifest for a specific object"""
        type = self.path.get_type_from_object(cdist_object)
        manifest = self.path.type_dir(type, "manifest")
        
        log.debug("%s: Running %s", cdist_object, manifest)
        if os.path.exists(manifest):
            env = { "__object" :    self.path.object_dir(cdist_object), 
                    "__object_id":  self.path.get_object_id_from_object(cdist_object),
                    "__object_fq":  cdist_object,
                    "__type":       self.path.type_dir(type)
                    }
            self.run_manifest(manifest, extra_env=env)

    def run_manifest(self, manifest, extra_env=None):
        """Run a manifest"""
        log.debug("Running manifest %s, env=%s", manifest, extra_env)
        env = os.environ.copy()
        env['PATH'] = self.path.bin_dir + ":" + env['PATH']

        # Information required in every manifest
        env['__target_host']            = self.target_host
        env['__global']                 = self.path.out_dir
        
        # Submit debug flag to manifest, can be used by emulator and types
        if self.debug:
            env['__debug']                  = "yes"

        # Required for recording source
        env['__cdist_manifest']         = manifest

        # Required to find types
        env['__cdist_type_base_dir']    = self.path.type_base_dir

        # Other environment stuff
        if extra_env:
            env.update(extra_env)

        cdist.exec.shell_run_or_debug_fail(manifest, [manifest], env=env)

    def object_run(self, cdist_object, mode):
        """Run gencode or code for an object"""
        log.debug("Running %s from %s", mode, cdist_object)

        # FIXME: replace with new object interface
        file=os.path.join(self.path.object_dir(cdist_object), "require")
        requirements = cdist.path.file_to_list(file)
        type = self.path.get_type_from_object(cdist_object)
            
        for requirement in requirements:
            log.debug("Object %s requires %s", cdist_object, requirement)
            self.object_run(requirement, mode=mode)

        #
        # Setup env Variable:
        #
        env = os.environ.copy()
        env['__target_host']    = self.target_host
        env['__global']         = self.path.out_dir
        env["__object"]         = self.path.object_dir(cdist_object)
        env["__object_id"]      = self.path.get_object_id_from_object(cdist_object)
        env["__object_fq"]      = cdist_object
        env["__type"]           = self.path.type_dir(type)

        if mode == "gencode":
            paths = [
                self.path.type_dir(type, "gencode-local"),
                self.path.type_dir(type, "gencode-remote")
            ]
            for bin in paths:
                if os.path.isfile(bin):
                    # omit "gen" from gencode and use it for output base
                    outfile=os.path.join(self.path.object_dir(cdist_object), 
                        os.path.basename(bin)[3:])

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

                        # Mark object as changed
                        open(os.path.join(self.path.object_dir(cdist_object), "changed"), "w").close()


        if mode == "code":
            local_dir   = self.path.object_dir(cdist_object)
            remote_dir  = self.path.remote_object_dir(cdist_object)

            bin = os.path.join(local_dir, "code-local")
            if os.path.isfile(bin):
                cdist.exec.run_or_fail([bin])
                

            local_remote_code = os.path.join(local_dir, "code-remote")
            remote_remote_code = os.path.join(remote_dir, "code-remote")
            if os.path.isfile(local_remote_code):
                self.path.transfer_file(local_remote_code, remote_remote_code)
                cdist.exec.run_or_fail([remote_remote_code], remote_prefix=True)
                
    ### Cleaned / check functions: Round 1 :-) #################################
    def run_type_explorer(self, cdist_object):
        """Run type specific explorers for objects"""

        type = cdist_object.type
        # FIXME
        self.path.transfer_type_explorers(type)

        cmd = []
        cmd.append("__explorer="        + self.context.remote_global_explorer_dir)
        cmd.append("__type_explorer="   + type.explorer_remote_dir)
        cmd.append("__object="          + object.path_remote)
        cmd.append("__object_id="       + object.object_id)
        cmd.append("__object_fq="       + cdist_object)

        # Need to transfer at least the parameters for objects to be useful
        self.path.transfer_object_parameter(cdist_object)

        explorers = self.path.list_type_explorers(type)
        for explorer in explorers:
            remote_cmd = cmd + [os.path.join(type.explorer_remote_dir, explorer)]
            output = os.path.join(cdist_object.explorer_output_dir(), explorer)
            output_fd = open(output, mode='w')
            log.debug("%s exploring %s using %s storing to %s", 
                            cdist_object, explorer, remote_cmd, output)
                        
            cdist.exec.run_or_fail(remote_cmd, stdout=output_fd, remote_prefix=True)
            output_fd.close()


    def link_emulator(self):
        """Link emulator to types"""
        src = os.path.abspath(self.exec_path)
        for type in cdist.core.Type.list_types():
            log.debug("Linking emulator: %s to %s", source, destination)
            dst = os.path.join(self.context.bin_dir, type.name)
            # FIXME: handle exception / make it more beautiful
            os.symlink(src, dst)

    def run_global_explorers(self):
        """Run global explorers"""
        log.info("Running global explorers")

        src = cdist.core.GlobalExplorer.base_dir
        dst = cdist.core.GlobalExplorer.remote_base_dir

        self.context.transfer_dir(src, dst)

        for explorer in cdist.core.GlobalExplorer.list_explorers():
            output_fd = open(explorer.out_path, mode='w')
            cmd = []
            cmd.append("__explorer=" + cdist.core.GlobalExplorer.remote_base_dir)
            cmd.append(explorer.remote_path)

            cdist.exec.run_or_fail(cmd, stdout=output_fd, remote_prefix=True)
            output_fd.close()


    def stage_run(self):
        """The final (and real) step of deployment"""
        log.info("Generating and executing code")
        # Now do the final steps over the existing objects
        for cdist_object in cdist.core.Object.list_objects():
            log.debug("Run object: %s", cdist_object)
            self.object_run(cdist_object, mode="gencode")
            self.object_run(cdist_object, mode="code")

    def deploy_to(self):
        """Mimic the old deploy to: Deploy to one host"""
        log.info("Deploying to " + self.target_host)
        self.stage_prepare()
        self.stage_run()

    def deploy_and_cleanup(self):
        """Do what is most often done: deploy & cleanup"""
        self.deploy_to()
        self.cleanup()

    def init_deploy(self):
        """Ensure the base directories are cleaned up"""
        log.debug("Creating clean directory structure")

        self.path.remove_remote_dir(cdist.path.REMOTE_BASE_DIR)
        self.path.remote_mkdir(cdist.path.REMOTE_BASE_DIR)
        self.link_emulator()
    
    def stage_prepare(self):
        """Do everything for a deploy, minus the actual code stage"""
        self.init_deploy()
        self.run_global_explorers()
        self.run_initial_manifest()
        
        log.info("Running object manifests and type explorers")

        log.debug("Searching for objects in " + cdist.core.Object.base_dir())

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

    # FIXME Move into configinstall
    def transfer_object_parameter(self, cdist_object):
        """Transfer the object parameter to the remote destination"""
        # Create base path before using mkdir -p
        self.remote_mkdir(self.remote_object_parameter_dir(cdist_object))

        # Synchronise parameter dir afterwards
        self.transfer_dir(self.object_parameter_dir(cdist_object), 
                                self.remote_object_parameter_dir(cdist_object))

    # FIXME Move into configinstall
    def transfer_global_explorers(self):
        """Transfer the global explorers"""
        self.remote_mkdir(REMOTE_GLOBAL_EXPLORER_DIR)
        self.transfer_dir(self.global_explorer_dir, REMOTE_GLOBAL_EXPLORER_DIR)

    # FIXME Move into configinstall
    def transfer_type_explorers(self, type):
        """Transfer explorers of a type, but only once"""
        if type.transferred_explorers:
            log.debug("Skipping retransfer for explorers of %s", type)
            return
        else:
            # Do not retransfer
            type.transferred_explorers = True

        # FIXME: Can be explorer_path or explorer_dir, I don't care.
        src = type.explorer_path()
        dst = type.remote_explorer_path()

        # Transfer if there is at least one explorer
        if len(type.explorers) > 0:
            # Ensure that the path exists
            self.remote_mkdir(dst)
            self.transfer_dir(src, dst)
