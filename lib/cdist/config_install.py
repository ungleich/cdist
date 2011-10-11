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
import shutil
import sys
import tempfile
import time

import cdist.core
import cdist.context
import cdist.exec
import cdist.explorer
#import cdist.manifest

class ConfigInstall(object):
    """Cdist main class to hold arbitrary data"""

    def __init__(self, context): 

        self.context = context

        self.exec_wrapper   = cdist.exec.Wrapper(
            target_host = self.context.target_host,
            remote_exec=self.context.remote_exec,
            remote_copy=self.context.remote_copy)

        self.explorer = cdist.explorer.Explorer(self.context)
        #self.manifest = cdist.manifest.Mamifest()

        self.log = logging.getLogger(self.context.target_host)

        # Setup env to be used by others - FIXME
        self.__init_env()

        # Create directories
        self.__init_local_paths()
        self.__init_remote_paths()

    def __init_remote_paths(self):
        """Initialise remote directory structure"""
        self.exec_wrapper.remove_remote_path(self.context.remote_base_path)
        self.exec_wrapper.remote_mkdir(self.context.remote_base_path)
        self.exec_wrapper.remote_mkdir(self.context.remote_conf_path)

    def __init_local_paths(self):
        """Initialise local directory structure"""

        # Create base dir, if user supplied and not existing
        if not os.path.isdir(self.context.base_path):
            os.mkdir(self.context.base_path)
            
        # FIXME: raise more beautiful exception / Steven: handle exception
        os.mkdir(self.context.out_path)
        os.mkdir(self.global_explorer_out_path)
        os.mkdir(self.context.bin_path)

    # FIXME: remove this function, only expose ENV
    # explicitly!
    def __init_env(self):
        """Environment usable for other stuff"""
        os.environ['__target_host'] = self.context.target_host
        if self.context.debug:
            os.environ['__debug'] = "yes"

    def cleanup(self):
        log.debug("Saving " + self.context.out_path + " to " + self.context.cache_path)
        if os.path.exists(self.context.cache_path):
            shutil.rmtree(self.context.cache_path)
        shutil.move(self.context.out_path, self.context.cache_path)

    def object_prepare(self, cdist_object):
        """Prepare object: Run type explorer + manifest"""
        log.debug("Preparing object: " + cdist_object.name)
        self.run_type_explorer(cdist_object)
        self.run_type_manifest(cdist_object)
        cdist_object.prepared = True

    def object_run(self, cdist_object):
        """Run gencode and code for an object"""
        log.debug("Running object %s", cdist_object)

        # Catch requirements, which re-call us
        if cdist_object.ran:
            return

        cdist_type = cdist_object.type
            
        for requirement in cdist_object.requirements:
            log.debug("Object %s requires %s", cdist_object, requirement)
            self.object_run(requirement)

        #
        # Setup env Variable:
        #
        env = os.environ.copy()
        env['__target_host']    = self.context.target_host
        env['__global']         = self.context.out_path
        env["__object"]         = os.path.join(self.object_base_path, cdist_object.path)
        env["__object_id"]      = cdist_object.object_id
        env["__object_fq"]      = cdist_object.name
        env["__type"]           = cdist_type.name

        # gencode
        for cmd in ["local", "remote"]:
            bin = os.path.join(self.type_base_path,
                    getattr(cdist_type, "gencode_" + cmd + "_path"))

            if os.path.isfile(bin):
                outfile = os.path.join(self.object_base_path,
                            getattr(cdist_object, "code_" + cmd + "_path"))

                outfile_fd = open(outfile, "w")

                # Need to flush to ensure our write is done before stdout write
                # FIXME: code header still needed?
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
        local_remote_code   = os.path.join(self.object_base_path,
            cdist_object.code_remote_path)
        remote_remote_code  = os.path.join(self.remote_object_path,
            cdist_object.code_remote_path)
        if os.path.isfile(local_remote_code):
            self.context.transfer_path(local_remote_code, remote_remote_code)
            cdist.exec.run_or_fail([remote_remote_code], remote_prefix=True)

        cdist_object.ran = True

    def link_emulator(self):
        """Link emulator to types"""
        src = os.path.abspath(self.context.exec_path)
        for cdist_type in cdist.core.Type.list_types(self.type_base_path):
            dst = os.path.join(self.context.bin_path, cdist_type.name)
            log.debug("Linking emulator: %s to %s", src, dst)

            # FIXME: handle exception / make it more beautiful / Steven: raise except :-)
            os.symlink(src, dst)

    def deploy_to(self):
        """Mimic the old deploy to: Deploy to one host"""
        log.info("Deploying to " + self.context.target_host)
        self.stage_prepare()
        self.stage_run()

    def deploy_and_cleanup(self):
        """Do what is most often done: deploy & cleanup"""
        start_time = time.time()
        self.deploy_to()
        self.cleanup()
        log.info("Finished run of %s in %s seconds", 
            self.context.target_host, time.time() - start_time)

    def stage_prepare(self):
        """Do everything for a deploy, minus the actual code stage"""
        self.link_emulator()
        self.run_global_explorers()
        self.run_initial_manifest()
        
        log.info("Running object manifests and type explorers")

        # Continue process until no new objects are created anymore
        new_objects_created = True
        while new_objects_created:
            new_objects_created = False
            for cdist_object in cdist.core.Object.list_objects(self.object_base_path,
                                                               self.type_base_path):
                if cdist_object.prepared:
                    log.debug("Skipping rerun of object %s", cdist_object)
                    continue
                else:
                    self.object_prepare(cdist_object)
                    new_objects_created = True

    def stage_run(self):
        """The final (and real) step of deployment"""
        log.info("Generating and executing code")
        for cdist_object in cdist.core.Object.list_objects(self.object_base_path,
                                                           self.type_base_path):
            log.debug("Run object: %s", cdist_object)
            self.object_run(cdist_object)
