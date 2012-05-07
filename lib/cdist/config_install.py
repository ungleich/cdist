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
import itertools
import pprint

import cdist
from cdist import core
from cdist import resolver


class ConfigInstall(object):
    """Cdist main class to hold arbitrary data"""

    def __init__(self, context):

        self.context = context
        self.log = logging.getLogger(self.context.target_host)

        # For easy access
        self.local = context.local
        self.remote = context.remote

        # Initialise local directory structure
        self.local.create_directories()
        # Initialise remote directory structure
        self.remote.create_directories()

        self.explorer = core.Explorer(self.context.target_host, self.local, self.remote)
        self.manifest = core.Manifest(self.context.target_host, self.local)
        self.code = core.Code(self.context.target_host, self.local, self.remote)

    def cleanup(self):
        # FIXME: move to local?
        destination = os.path.join(self.local.cache_path, self.context.target_host)
        self.log.debug("Saving " + self.local.out_path + " to " + destination)
        if os.path.exists(destination):
            shutil.rmtree(destination)
        shutil.move(self.local.out_path, destination)

    def deploy_to(self):
        """Mimic the old deploy to: Deploy to one host"""
        self.stage_prepare()
        self.stage_run()

    def deploy_and_cleanup(self):
        """Do what is most often done: deploy & cleanup"""
        start_time = time.time()
        self.deploy_to()
        self.cleanup()
        self.log.info("Finished successful run in %s seconds",
            time.time() - start_time)

    def stage_prepare(self):
        """Do everything for a deploy, minus the actual code stage"""
        self.local.link_emulator(self.context.exec_path)
        self.explorer.run_global_explorers(self.local.global_explorer_out_path)
        self.manifest.run_initial_manifest(self.context.initial_manifest)

        self.log.info("Running object manifests and type explorers")

        # Continue process until no new objects are created anymore
        new_objects_created = True
        while new_objects_created:
            new_objects_created = False
            for cdist_object in core.CdistObject.list_objects(self.local.object_path,
                                                         self.local.type_path):
                if cdist_object.state == core.CdistObject.STATE_PREPARED:
                    self.log.debug("Skipping re-prepare of object %s", cdist_object)
                    continue
                else:
                    self.object_prepare(cdist_object)
                    new_objects_created = True

    def object_prepare(self, cdist_object):
        """Prepare object: Run type explorer + manifest"""
        self.log.info("Running manifest and explorers for " + cdist_object.name)
        self.explorer.run_type_explorers(cdist_object)
        self.manifest.run_type_manifest(cdist_object)
        cdist_object.state = core.CdistObject.STATE_PREPARED

    def object_run(self, cdist_object):
        """Run gencode and code for an object"""
        self.log.debug("Trying to run object " + cdist_object.name)
        if cdist_object.state == core.CdistObject.STATE_DONE:
            # TODO: remove once we are sure that this really never happens.
            raise cdist.Error("Attempting to run an already finished object: %s", cdist_object)

        cdist_type = cdist_object.cdist_type

        # Generate
        self.log.info("Generating and executing code for " + cdist_object.name)
        cdist_object.code_local = self.code.run_gencode_local(cdist_object)
        cdist_object.code_remote = self.code.run_gencode_remote(cdist_object)
        if cdist_object.code_local or cdist_object.code_remote:
            cdist_object.changed = True

        # Execute
        if cdist_object.code_local:
            self.code.run_code_local(cdist_object)
        if cdist_object.code_remote:
            self.code.transfer_code_remote(cdist_object)
            self.code.run_code_remote(cdist_object)

        # Mark this object as done
        self.log.debug("Finishing run of " + cdist_object.name)
        cdist_object.state = core.CdistObject.STATE_DONE

    def stage_run(self):
        """The final (and real) step of deployment"""
        self.log.info("Generating and executing code")

        objects = core.CdistObject.list_objects(
            self.local.object_path,
            self.local.type_path)

        dependency_resolver = resolver.DependencyResolver(objects)
        self.log.debug(pprint.pformat(dependency_resolver.dependencies))

        for cdist_object in dependency_resolver:
            self.log.debug("Run object: %s", cdist_object)
            self.object_run(cdist_object)
