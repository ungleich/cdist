#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2010-2013 Nico Schottelius (nico-cdist at schottelius.org)
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
import time
import pprint

import cdist
from cdist import core

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

    def run(self):
        """Do what is most often done: deploy & cleanup"""
        start_time = time.time()

        self.explorer.run_global_explorers(self.context.local.global_explorer_out_path)
        self.manifest.run_initial_manifest(self.context.initial_manifest)
        self.iterate_until_finished()

        self.cleanup()
        self.log.info("Finished successful run in %s seconds", time.time() - start_time)


    def object_list(self):
        """Short name for object list retrieval"""
        for cdist_object in core.CdistObject.list_objects(self.context.local.object_path,
                                                         self.context.local.type_path):
            yield cdist_object

    def iterate_until_finished(self):
        # Continue process until no new objects are created anymore

        objects_changed = True

        while objects_changed:
            objects_changed  = False

            for cdist_object in self.object_list():
                if cdist_object.requirements_unfinished(cdist_object.requirements):
                    """We cannot do anything for this poor object"""
                    continue

                if cdist_object.state == core.CdistObject.STATE_UNDEF:
                    """Prepare the virgin object"""

                    self.object_prepare(cdist_object)
                    objects_changed = True

                if cdist_object.requirements_unfinished(cdist_object.autorequire):
                    """The previous step created objects we depend on - wait for them"""
                    continue

                if cdist_object.state == core.CdistObject.STATE_PREPARED:
                    self.object_run(cdist_object)
                    objects_changed = True

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

                for requirement in cdist_object.requirements_unfinished(cdist_object.requirements):
                    requirement_names.append(requirement.name)

                for requirement in cdist_object.requirements_unfinished(cdist_object.autorequire):
                    autorequire_names.append(requirement.name)

                requirements = ", ".join(requirement_names)
                autorequire  = ", ".join(autorequire_names)
                info_string.append("%s requires: %s autorequires: %s" % (cdist_object.name, requirements, autorequire))

            raise cdist.Error("The requirements of the following objects could not be resolved: %s" %
                ("; ".join(info_string)))

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
