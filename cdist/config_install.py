#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2010-2012 Nico Schottelius (nico-cdist at schottelius.org)
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
import itertools
import pprint

import cdist
from cdist import core
from cdist.resolver import CircularReferenceError


class ConfigInstall(object):
    """Cdist main class to hold arbitrary data"""

    def __init__(self, context):

        self.context = context
        self.log = logging.getLogger(self.context.target_host)

        # Initialise local directory structure
        self.context.local.create_files_dirs()
        # Initialise remote directory structure
        self.context.remote.create_files_dirs()

        self.explorer = core.Explorer(self.context.target_host, self.context.local, self.context.remote)
        self.manifest = core.Manifest(self.context.target_host, self.context.local)
        self.code = core.Code(self.context.target_host, self.context.local, self.context.remote)

        # Add switch to disable code execution
        self.dry_run = False

    def cleanup(self):
        # FIXME: move to local?
        destination = os.path.join(self.context.local.cache_path, self.context.target_host)
        self.log.debug("Saving " + self.context.local.out_path + " to " + destination)
        if os.path.exists(destination):
            shutil.rmtree(destination)
        shutil.move(self.context.local.out_path, destination)

    def deploy_to(self):
        """Mimic the old deploy to: Deploy to one host"""
        self.tree_deploy()

    def deploy_and_cleanup(self):
        """Do what is most often done: deploy & cleanup"""
        start_time = time.time()
        self.deploy_to()
        self.cleanup()
        self.log.info("Finished successful run in %s seconds",
            time.time() - start_time)

    def tree_deploy(self):
        """ Walks the dependency tree executing manifests and object code in strict dependency order
        waiting to execute manifests/resolvers till the dependencies object code has been executed
        """
        self.explorer.run_global_explorers(self.context.local.global_explorer_out_path)
        self.manifest.run_initial_manifest(self.context.initial_manifest)

        self.log.info("Running object manifests and type explorers")

        deps = list(core.CdistObject.list_objects(self.context.local.object_path,self.context.local.type_path))
        ready_objects = {}
        seen_objs = set()
        while deps:
            obj = deps[-1]
            if obj.name in ready_objects:
                deps.pop()
                continue
            seen_objs.add(obj.name)
            unmet_reqs = [ req for req in obj.requirements if req not in ready_objects ]
            if unmet_reqs:
                seen_reqs = [req for req in unmet_reqs if req in seen_objs]
                if seen_reqs:
                    raise CircularReferenceError(obj,obj.object_from_name(seen_reqs[0]))
                deps.extend(obj.find_requirements_by_name(unmet_reqs))
                continue
            if obj.state != core.CdistObject.STATE_PREPARED:
                self.object_prepare(obj)

            unmet_autoreqs = [ req for req in obj.autorequire if req not in ready_objects]
            if unmet_autoreqs:
                seen_reqs = [req for req in unmet_autoreqs if req in seen_objs]
                if seen_reqs:
                    raise CircularReferenceError(obj,obj.object_from_name(seen_reqs[0]))
                deps.extend(obj.find_requirements_by_name(unmet_autoreqs))
                continue

            self.object_run(obj)
            seen_objs.remove(obj.name)
            ready_objects[obj.name] = obj
            deps.pop()


    def object_prepare(self, cdist_object):
        """Prepare object: Run type explorer + manifest"""
        self.log.info("Running manifest and explorers for " + cdist_object.name)
        self.explorer.run_type_explorers(cdist_object)
        self.manifest.run_type_manifest(cdist_object)
        cdist_object.state = core.CdistObject.STATE_PREPARED

    def object_run(self, cdist_object, dry_run=False):
        """Run gencode and code for an object"""
        self.log.debug("Trying to run object " + cdist_object.name)
        if cdist_object.state == core.CdistObject.STATE_DONE:
            raise cdist.Error("Attempting to run an already finished object: %s", cdist_object)


        # Generate
        self.log.info("Generating and executing code for " + cdist_object.name)
        cdist_object.code_local = self.code.run_gencode_local(cdist_object)
        cdist_object.code_remote = self.code.run_gencode_remote(cdist_object)
        if cdist_object.code_local or cdist_object.code_remote:
            cdist_object.changed = True

        # Execute
        if not dry_run:
            if cdist_object.code_local:
                self.code.run_code_local(cdist_object)
            if cdist_object.code_remote:
                self.code.transfer_code_remote(cdist_object)
                self.code.run_code_remote(cdist_object)

        # Mark this object as done
        self.log.debug("Finishing run of " + cdist_object.name)
        cdist_object.state = core.CdistObject.STATE_DONE
