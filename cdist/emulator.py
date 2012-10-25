# -*- coding: utf-8 -*-
#
# 2011-2012 Nico Schottelius (nico-cdist at schottelius.org)
# 2012 Steven Armstrong (steven-cdist at armstrong.cc)
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
import sys

import cdist
from cdist import core

class Emulator(object):
    def __init__(self, argv):
        self.argv           = argv
        self.object_id      = False

        self.global_path    = os.environ['__global']
        self.target_host    = os.environ['__target_host']

        # Internally only
        self.object_source  = os.environ['__cdist_manifest']
        self.type_base_path = os.environ['__cdist_type_base_path']

        self.object_base_path = os.path.join(self.global_path, "object")

        self.type_name      = os.path.basename(argv[0])
        self.cdist_type     = core.CdistType(self.type_base_path, self.type_name)

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
        self.save_stdin()
        self.record_requirements()
        self.record_auto_requirements()
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

        parser = argparse.ArgumentParser(add_help=False, argument_default=argparse.SUPPRESS)

        for parameter in self.cdist_type.required_parameters:
            argument = "--" + parameter
            parser.add_argument(argument, dest=parameter, action='store', required=True)
        for parameter in self.cdist_type.required_multiple_parameters:
            argument = "--" + parameter
            parser.add_argument(argument, dest=parameter, action='append', required=True)
        for parameter in self.cdist_type.optional_parameters:
            argument = "--" + parameter
            parser.add_argument(argument, dest=parameter, action='store', required=False)
        for parameter in self.cdist_type.optional_multiple_parameters:
            argument = "--" + parameter
            parser.add_argument(argument, dest=parameter, action='append', required=False)
        for parameter in self.cdist_type.boolean_parameters:
            argument = "--" + parameter
            parser.add_argument(argument, dest=parameter, action='store_const', const='')

        # If not singleton support one positional parameter
        if not self.cdist_type.is_singleton:
            parser.add_argument("object_id", nargs=1)

        # And finally parse/verify parameter
        self.args = parser.parse_args(self.argv[1:])
        self.log.debug('Args: %s' % self.args)


    def setup_object(self):
        # Setup object_id - FIXME: unset / do not setup anymore!
        if self.cdist_type.is_singleton:
            self.object_id = "singleton"
        else:
            self.object_id = self.args.object_id[0]
            del self.args.object_id

        # Instantiate the cdist object we are defining
        self.cdist_object = core.CdistObject(self.cdist_type, self.object_base_path, self.object_id)

        # Create object with given parameters
        self.parameters = {}
        for key,value in vars(self.args).items():
            if value is not None:
                self.parameters[key] = value

        if self.cdist_object.exists:
            if self.cdist_object.parameters != self.parameters:
                raise cdist.Error("Object %s already exists with conflicting parameters:\n%s: %s\n%s: %s"
                    % (self.cdist_object.name, " ".join(self.cdist_object.source), self.cdist_object.parameters, self.object_source, self.parameters)
            )
        else:
            self.cdist_object.create()
            self.cdist_object.parameters = self.parameters

        # Record / Append source
        self.cdist_object.source.append(self.object_source)

    chunk_size = 8192
    def _read_stdin(self):
        return sys.stdin.buffer.read(self.chunk_size)
    def save_stdin(self):
        """If something is written to stdin, save it in the object as
        $__object/stdin so it can be accessed in manifest and gencode-*
        scripts.
        """
        if not sys.stdin.isatty():
            try:
                # go directly to file instead of using CdistObject's api
                # as that does not support streaming
                path = os.path.join(self.cdist_object.absolute_path, 'stdin')
                with open(path, 'wb') as fd:
                    chunk = self._read_stdin()
                    while chunk:
                        fd.write(chunk)
                        chunk = self._read_stdin()
            except EnvironmentError as e:
                raise cdist.Error('Failed to read from stdin: %s' % e)

    def record_requirements(self):
        """record requirements"""

        if "require" in os.environ:
            requirements = os.environ['require']
            self.log.debug("reqs = " + requirements)
            for requirement in requirements.split(" "):
                # Ignore empty fields - probably the only field anyway
                if len(requirement) == 0: continue

                # Raises an error, if object cannot be created
                cdist_object = self.cdist_object.object_from_name(requirement)

                self.log.debug("Recording requirement: " + requirement)

                # Save the sanitised version, not the user supplied one
                # (__file//bar => __file/bar)
                # This ensures pattern matching is done against sanitised list
                self.cdist_object.requirements.append(cdist_object.name)

    def record_auto_requirements(self):
        """An object shall automatically depend on all objects that it defined in it's type manifest.
        """
        # __object_name is the name of the object whose type manifest is currently executed
        __object_name = os.environ.get('__object_name', None)
        if __object_name:
            # The object whose type manifest is currently run
            parent = self.cdist_object.object_from_name(__object_name)
            # The object currently being defined
            current_object = self.cdist_object
            # As parent defined current_object it shall automatically depend on it.
            # But only if the user hasn't said otherwise.
            # Must prevent circular dependencies.
            if not parent.name in current_object.requirements:
                parent.autorequire.append(current_object.name)
