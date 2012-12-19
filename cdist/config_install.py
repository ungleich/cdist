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
from cdist import resolver


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
        self.explorer.run_global_explorers(self.context.local.global_explorer_out_path)
        self.manifest.run_initial_manifest(self.context.initial_manifest)

        self.log.info("Running object manifests and type explorers")

        # Continue process until no new objects are created anymore
        new_objects_created = True
        while new_objects_created:
            new_objects_created = False
            for cdist_object in core.CdistObject.list_objects(self.context.local.object_path,
                                                         self.context.local.type_path):
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

    def object_run(self, cdist_object, dry_run=False):
        """Run gencode and code for an object"""
        self.log.debug("Trying to run object " + cdist_object.name)
        if cdist_object.state == core.CdistObject.STATE_DONE:
            raise cdist.Error("Attempting to run an already finished object: %s", cdist_object)

        cdist_type = cdist_object.cdist_type

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

    def stage_run(self):
        """The final (and real) step of deployment"""
        self.log.info("Generating and executing code")

        # FIXME: think about parallel execution (same for stage_prepare)
        self.all_resolved = False
        while not self.all_resolved:
            self.stage_run_iterate()

    def stage_run_iterate(self):
        """
        Run one iteration of the run

        To be repeated until all objects are done
        """
        objects = list(core.CdistObject.list_objects(self.context.local.object_path, self.context.local.type_path))
        object_state_list=' '.join('%s:%s:%s:%s' % (o, o.state, o.all_requirements, o.satisfied_requirements) for o in objects)

        self.log.debug("Object state (name:state:requirements:satisfied): %s" % object_state_list)

        objects_changed = False
        self.all_resolved = True
        for cdist_object in objects:
            if not cdist_object.state == cdist_object.STATE_DONE:
                self.all_resolved = False
                self.log.debug("Object %s not done" % cdist_object.name)
                if cdist_object.satisfied_requirements:
                    self.log.debug("Running object %s with satisfied requirements" % cdist_object.name)
                    self.object_run(cdist_object, self.dry_run)
                    objects_changed = True

        self.log.debug("All resolved: %s Objects changed: %s" % (self.all_resolved, objects_changed))

        # Not all are resolved, but nothing has been changed => bad dependencies!
        if not objects_changed and not self.all_resolved:
            # Create list of unfinished objects + their requirements for print

            evil_objects = []
            good_objects = []
            for cdist_object in objects:
                if not cdist_object.state == cdist_object.STATE_DONE:
                    evil_objects.append("%s: required: %s, autorequired: %s" %
                        (cdist_object.name, cdist_object.requirements, cdist_object.autorequire))
                else:
                    evil_objects.append("%s (%s): required: %s, autorequired: %s" %
                        (cdist_object.state, cdist_object.name, 
                        cdist_object.requirements, cdist_object.autorequire))

            errormessage = "Cannot solve requirements for the following objects: %s - solved: %s" % (",".join(evil_objects), ",".join(good_objects))
            raise cdist.Error(errormessage)
