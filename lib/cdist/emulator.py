# -*- coding: utf-8 -*-
#
# 2011 Nico Schottelius (nico-cdist at schottelius.org)
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

import argparse
import logging
import os

import cdist
from cdist import core


class IllegalRequirementError(cdist.Error):
    def __init__(self, requirement, message=None):
        self.requirement = requirement
        self.message = message or 'Illegal requirement'

    def __str__(self):
        return '%s: %s' % (self.message, self.requirement)

class Emulator(object):
    def __init__(self, argv):
        self.argv           = argv
        self.object_id      = False

        self.global_path    = os.environ['__global']
        self.object_source  = os.environ['__cdist_manifest']
        self.target_host    = os.environ['__target_host']
        self.type_base_path = os.environ['__cdist_type_base_path']

        self.object_base_path = os.path.join(self.global_path, "object")

        self.type_name      = os.path.basename(argv[0])
        self.cdist_type     = core.Type(self.type_base_path, self.type_name)

        self.__init_log()

    def filter(self, record):
        """Add hostname and object to logs via logging Filter"""

        prefix = self.target_host + ": (emulator)"

        if self.object_id:
            prefix = prefix + " " + self.type_name + "/" + self.object_id

        record.msg = prefix + ": " + record.msg

        return True

    def run(self):
        """Emulate type commands (i.e. __file and co)"""

        if '__install' in os.environ:
            if not self.cdist_type.is_install:
                self.log.debug("Running in install mode, ignoring non install type")
                return True

        self.commandline()
        self.setup_object()
        self.record_requirements()
        self.log.debug("Finished %s %s" % (self.cdist_object.path, self.parameters))

    def __init_log(self):
        """Setup logging facility"""
        logformat = '%(levelname)s: %(message)s'
        logging.basicConfig(format=logformat)

        if '__cdist_debug' in os.environ:
            logging.root.setLevel(logging.DEBUG)
        else:
            logging.root.setLevel(logging.INFO)

        self.log            = logging.getLogger(__name__)
        self.log.addFilter(self)

    def commandline(self):
        """Parse command line"""

        parser = argparse.ArgumentParser(add_help=False)

        for parameter in self.cdist_type.optional_parameters:
            argument = "--" + parameter
            parser.add_argument(argument, action='store', required=False)
        for parameter in self.cdist_type.required_parameters:
            argument = "--" + parameter
            parser.add_argument(argument, action='store', required=True)

        # If not singleton support one positional parameter
        if not self.cdist_type.is_singleton:
            parser.add_argument("object_id", nargs=1)

        # And finally parse/verify parameter
        self.args = parser.parse_args(self.argv[1:])
        self.log.debug('Args: %s' % self.args)


    def setup_object(self):
        # FIXME: verify object id

        # Setup object_id
        if self.cdist_type.is_singleton:
            self.object_id = "singleton"
        else:
            self.object_id = self.args.object_id[0]
            del self.args.object_id

            # strip leading slash from object_id
            self.object_id = self.object_id.lstrip('/')

        # Instantiate the cdist object we are defining
        self.cdist_object = core.Object(self.cdist_type, self.object_base_path, self.object_id)

        # Create object with given parameters
        self.parameters = {}
        for key,value in vars(self.args).items():
            if value is not None:
                self.parameters[key] = value

        if self.cdist_object.exists:
            if self.cdist_object.parameters != self.parameters:
                raise cdist.Error("Object %s already exists with conflicting parameters:\n%s: %s\n%s: %s"
                    % (self.cdist_object, " ".join(self.cdist_object.source), self.cdist_object.parameters, self.object_source, self.parameters)
            )
        else:
            self.cdist_object.create()
            self.cdist_object.parameters = self.parameters

    def record_requirements(self):
        """record requirements"""

        if "require" in os.environ:
            requirements = os.environ['require']
            self.log.debug("reqs = " + requirements)
            for requirement in requirements.split(" "):
                # Ignore empty fields - probably the only field anyway
                if len(requirement) == 0:
                    continue

                self.log.debug("Recording requirement: " + requirement)
                requirement_parts = requirement.split(os.sep, 1)
                requirement_type_name = requirement_parts[0]
                try:
                    requirement_object_id = requirement_parts[1]
                except IndexError:
                    # no object id, assume singleton
                    requirement_object_id = 'singleton'
                
                # Remove leading / from object id
                requirement_object_id = requirement_object_id.lstrip('/')

                # Instantiate type which fails if type does not exist
                requirement_type = core.Type(self.type_base_path, requirement_type_name)

                if requirement_object_id == 'singleton' \
                    and not requirement_type.is_singleton:
                    raise IllegalRequirementError(requirement, "Missing object_id and type is not a singleton.")

                # Instantiate object which fails if the object_id is illegal
                requirement_object = core.Object(requirement_type, self.object_base_path, requirement_object_id)

                # Construct cleaned up requirement with only one / :-)
                requirement = requirement_type_name + '/' + requirement_object_id
                self.cdist_object.requirements.append(requirement)

        # Record / Append source
        self.cdist_object.source.append(self.object_source)
