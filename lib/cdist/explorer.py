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
import cdist.exec

log = logging.getLogger(__name__)

CODE_HEADER = "#!/bin/sh -e\n"

class ConfigInstall:
    """Cdist main class to hold arbitrary data"""

    def __init__(self, 
        target_host,
        initial_manifest=False,
        base_path=False,
        exec_path=sys.argv[0],
        debug=False):

        self.target_host    = target_host

        self.debug          = debug

        # Only required for testing
        self.exec_path      = exec_path

        # Configure logging
        log.addFilter(self)

        # Base and Temp Base 
        self.base_path = (base_path or
            self.base_path = os.path.abspath(os.path.join(
                os.path.dirname(__file__), os.pardir, os.pardir))

        # Local input
        self.cache_path             = os.path.join(self.base_path, "cache", 
            self.target_host)
        self.conf_path              = os.path.join(self.base_path, "conf")

        self.global_explorer_path   = os.path.join(self.conf_path, "explorer")
        self.manifest_path          = os.path.join(self.conf_path, "manifest")
        self.type_base_path         = os.path.join(self.conf_path, "type")
        self.lib_path               = os.path.join(self.base_path, "lib")

        self.initial_manifest = (initial_manifest or
            os.path.join(self.manifest_path, "init"))

        # Local output
        if '__cdist_out_dir' in os.environ:
            self.out_path = os.environ['__cdist_out_dir']
        else:
            self.out_path = os.path.join(tempfile.mkdtemp(), "out")
        self.bin_path                 = os.path.join(self.out_path, "bin")
        self.global_explorer_out_path = os.path.join(self.out_path, "explorer")
        self.object_base_path         = os.path.join(self.out_path, "object")

        # Remote directory base
        if '__cdist_remote_out_dir' in os.environ:
            self.remote_base_path = os.environ['__cdist_remote_out_dir']
        else:
            self.remote_base_path = "/var/lib/cdist"

        self.remote_conf_path            = os.path.join(self.remote_base_path, "conf")
        self.remote_object_path          = os.path.join(self.remote_base_path, "object")

        self.remote_type_path            = os.path.join(self.remote_conf_path, "type")
        self.remote_global_explorer_path = os.path.join(self.remote_conf_path, "explorer")

        # Setup env to be used by others
        self.__init_env()

        # Create directories
        self.__init_local_paths()
        self.__init_remote_paths()


    def __init_remote_paths(self):
        """Initialise remote directory structure"""
        self.remove_remote_path(self.remote_base_path)
        self.remote_mkdir(self.remote_base_path)
        self.remote_mkdir(self.remote_conf_path)

    def __init_local_paths(self):
        """Initialise local directory structure"""

        # Create base dir, if user supplied and not existing
        if not os.path.isdir(self.base_path):
            os.mkdir(self.base_path)
            
        # FIXME: raise more beautiful exception / Steven: handle exception
        os.mkdir(self.out_path)
        os.mkdir(self.global_explorer_out_path)
        os.mkdir(self.bin_path)

    def __init_env(self):
        """Environment usable for other stuff"""
        os.environ['__target_host'] = self.target_host
        if self.debug:
            os.environ['__debug'] = "yes"


    def cleanup(self):
        # Do not use in __del__:
        # http://docs.python.org/reference/datamodel.html#customization
        # "other globals referenced by the __del__() method may already have been deleted 
        # or in the process of being torn down (e.g. the import machinery shutting down)"
        #
        log.debug("Saving " + self.out_path + " to " + self.cache_path)
        # FIXME: raise more beautiful exception / Steven: handle exception
        # Remove previous cache
        if os.path.exists(self.cache_path):
            shutil.rmtree(self.cache_path)
        shutil.move(self.out_path, self.cache_path)

    def filter(self, record):
        """Add hostname to logs via logging Filter"""

        record.msg = self.target_host + ": " + record.msg

        return True

    def run_initial_manifest(self):
        """Run the initial manifest"""
        log.info("Running initial manifest %s", self.initial_manifest)
        env = {  "__manifest" : self.manifest_path }
        self.run_manifest(self.initial_manifest, extra_env=env)

    def run_type_manifest(self, cdist_object):
        """Run manifest for a specific object"""
        cdist_type = cdist_object.type
        manifest_path = os.path.join(self.type_base_path,
                            cdist_type.manifest_path)
        
        log.debug("%s: Running %s", cdist_object.name, manifest_path)
        if os.path.exists(manifest_path):
            env = { "__object" :    os.path.join(self.object_base_path,
                                        cdist_object.path),
                    "__object_id":  cdist_object.object_id,
                    "__object_fq":  cdist_object.name,
                    "__type":       os.path.join(self.type_base_path,
                                        cdist_type.path)
                    }
            self.run_manifest(manifest_path, extra_env=env)

    def run_manifest(self, manifest_path, extra_env=None):
        """Run a manifest"""
        log.debug("Running manifest %s, env=%s", manifest_path, extra_env)
        env = os.environ.copy()
        env['PATH'] = self.bin_path + ":" + env['PATH']

        # Information required in every manifest
        env['__target_host']            = self.target_host
        env['__global']                 = self.out_path
        
        # Required for recording source in emulator
        env['__cdist_manifest']         = manifest_path

        # Required to find types in emulator
        env['__cdist_type_base_path']   = self.type_base_path

        # Other environment stuff
        if extra_env:
            env.update(extra_env)

        cdist.exec.shell_run_or_debug_fail(manifest_path, [manifest_path], env=env)

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
        env['__target_host']    = self.target_host
        env['__global']         = self.out_path
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
            self.transfer_path(local_remote_code, remote_remote_code)
            cdist.exec.run_or_fail([remote_remote_code], remote_prefix=True)

        cdist_object.ran = True

    def run_type_explorer(self, cdist_object):

    def run_type_explorer(self, cdist_object, remote_global_explorer_path, remote_type_path, remote_object_path, scp-hints, ssh-hints, object_base_path):

    def __init__(self, remote_global_explorer_path, remote_type_path, remote_object_path, exec-hint, object_base_path, global_explorer_out_path):

    def __init__(self, remote_global_explorer_path, remote_type_path, remote_object_path, exec-hint):

    def run_type_explorer(self, cdist_object)

        self.value = .,..
        return value

    def run_global_explorer(self)

    def __init__(self, remote_global_explorer_path, remote_type_path, remote_object_path, exec-hint):
        == 1x




    run_type_explorer()
    self.instance.value[obej
    
    c = ConfigInstall("foo")
    c.remote_global_explorer_path = "moo"

    def run_type_explorer(self, cdist_object)
        """Run type specific explorers for objects"""

        cdist_type = cdist_object.type
        self.transfer_type_explorers(cdist_type)

        cmd = []
        cmd.append("__explorer="        + self.remote_global_explorer_path)
        cmd.append("__type_explorer="   + os.path.join(
                                            self.remote_type_path,
                                            cdist_type.explorer_path))
        cmd.append("__object="          + os.path.join(
                                            self.remote_object_path,
                                            cdist_object.path))
        cmd.append("__object_id="       + cdist_object.object_id)
        cmd.append("__object_fq="       + cdist_object.name)

        # Need to transfer at least the parameters for objects to be useful
        self.transfer_object_parameter(cdist_object)

        for explorer in cdist_type.explorers:
            remote_cmd = cmd + [os.path.join(self.remote_type_path,
                cdist_type.explorer_path, explorer)]
            output = os.path.join(self.object_base_path,
                        cdist_object.explorer_path, explorer)
            output_fd = open(output, mode='w')
            log.debug("%s exploring %s using %s storing to %s", 
                            cdist_object, explorer, remote_cmd, output)
                        
            cdist.exec.run_or_fail(remote_cmd, stdout=output_fd, remote_prefix=True)
            output_fd.close()

        return outputs

    def link_emulator(self):
        """Link emulator to types"""
        src = os.path.abspath(self.exec_path)
        for cdist_type in cdist.core.Type.list_types(self.type_base_path):
            dst = os.path.join(self.bin_path, cdist_type.name)
            log.debug("Linking emulator: %s to %s", src, dst)

            # FIXME: handle exception / make it more beautiful / Steven: raise except :-)
            os.symlink(src, dst)

    def run_global_explorers(src_path, dst_path, remote_dst_path):

    def run_global_explorers(self):
        """Run global explorers"""
        log.info("Running global explorers")

        src_path = self.global_explorer_path
        dst_path = self.global_explorer_out_path
        remote_dst_path = self.remote_global_explorer_path

        self.transfer_path(src_path, remote_dst_path)

        for explorer in os.listdir(src_path):
            output_fd = open(os.path.join(dst_path, explorer), mode='w')
            cmd = []
            cmd.append("__explorer=" + remote_dst_path)
            cmd.append(os.path.join(remote_dst_path, explorer))

            cdist.exec.run_or_fail(cmd, stdout=output_fd, remote_prefix=True)
            output_fd.close()

    def deploy_to(self):
        """Mimic the old deploy to: Deploy to one host"""
        log.info("Deploying to " + self.target_host)
        self.stage_prepare()
        self.stage_run()

    def deploy_and_cleanup(self):
        """Do what is most often done: deploy & cleanup"""
        start_time = time.time()
        self.deploy_to()
        self.cleanup()
        log.info("Finished run of %s in %s seconds", 
            self.target_host, time.time() - start_time)

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

    def transfer_object_parameter(self, cdist_object):
        """Transfer the object parameter to the remote destination"""
        src  = os.path.join(self.object_base_path,
            cdist_object.parameter_path)
        dst = os.path.join(self.remote_object_path,
            cdist_object.parameter_path)

        # Synchronise parameter dir afterwards
        self.remote_mkdir(dst)
        self.transfer_path(src, dst)

    def transfer_global_explorers(self):
        """Transfer the global explorers"""
        self.remote_mkdir(self.remote_global_explorer_path)
        self.transfer_path(self.global_explorer_path, 
            self.remote_global_explorer_path)

    def transfer_type_explorers(self, cdist_type):
        """Transfer explorers of a type, but only once"""
        if cdist_type.transferred_explorers:
            log.debug("Skipping retransfer for explorers of %s", cdist_type)
            return
        else:
            log.debug("Ensure no retransfer for %s", cdist_type)
            # Do not retransfer
            cdist_type.transferred_explorers = True

        explorers = cdist_type.explorers

        if len(explorers) > 0:
            rel_path = cdist_type.explorer_path
            src = os.path.join(self.type_base_path, rel_path)
            dst = os.path.join(self.remote_type_path, rel_path)

            # Ensure full path until type exists:
            # /var/lib/cdist/conf/type/__directory/explorer
            # /var/lib/cdist/conf/type/__directory may not exist,
            # but remote_mkdir uses -p to fix this
            self.remote_mkdir(dst)
            self.transfer_path(src, dst)

    def remote_mkdir(self, directory):
        """Create directory on remote side"""
        cdist.exec.run_or_fail(["mkdir", "-p", directory], remote_prefix=True)

    def remove_remote_path(self, destination):
        """Ensure path on remote side vanished"""
        cdist.exec.run_or_fail(["rm", "-rf",  destination], remote_prefix=True)

    def transfer_path(self, source, destination):
        """Transfer directory and previously delete the remote destination"""
        self.remove_remote_path(destination)
        cdist.exec.run_or_fail(os.environ['__remote_copy'].split() +
            ["-r", source, self.target_host + ":" + destination])
