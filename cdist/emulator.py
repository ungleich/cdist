# -*- coding: utf-8 -*-
#
# 2011-2015 Nico Schottelius (nico-cdist at schottelius.org)
# 2012-2013 Steven Armstrong (steven-cdist at armstrong.cc)
# 2014 Daniel Heule (hda at sfs.biz)
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
from cdist import flock


class MissingRequiredEnvironmentVariableError(cdist.Error):
    def __init__(self, name):
        self.name = name
        self.message = ("Emulator requires the environment variable %s to be "
                        "setup" % self.name)

    def __str__(self):
        return self.message


class DefaultList(list):
    """Helper class to allow default values for optional_multiple parameters.

       @see https://groups.google.com/forum/#!msg/comp.lang.python/sAUvkJEDpRc/RnRymrzJVDYJ
    """
    def __copy__(self):
        return []

    @classmethod
    def create(cls, initial=None):
        if initial:
            return cls(initial.split('\n'))


class Emulator(object):
    def __init__(self, argv, stdin=sys.stdin.buffer, env=os.environ):
        self.argv = argv
        self.stdin = stdin
        self.env = env

        self.object_id = ''

        try:
            self.global_path = self.env['__global']
            self.target_host = (
                self.env['__target_host'],
                self.env['__target_hostname'],
                self.env['__target_fqdn']
            )

            # Internal variables
            self.object_source = self.env['__cdist_manifest']
            self.type_base_path = self.env['__cdist_type_base_path']
            self.object_marker = self.env['__cdist_object_marker']

        except KeyError as e:
            raise MissingRequiredEnvironmentVariableError(e.args[0])

        self.object_base_path = os.path.join(self.global_path, "object")
        self.typeorder_path = os.path.join(self.global_path, "typeorder")

        self.type_name = os.path.basename(argv[0])
        self.cdist_type = core.CdistType(self.type_base_path, self.type_name)

        # If set then object alreay exists and this var holds existing
        # requirements.
        self._existing_reqs = None

        self.__init_log()

    def run(self):
        """Emulate type commands (i.e. __file and co)"""

        self.commandline()
        self.init_object()

        # locking for parallel execution
        with flock.Flock(self.flock_path):
            self.setup_object()
            self.save_stdin()
            self.record_requirements()
            self.record_auto_requirements()
            self.log.trace("Finished %s %s" % (
                self.cdist_object.path, self.parameters))

    def __init_log(self):
        """Setup logging facility"""

        if '__cdist_log_level' in self.env:
            try:
                loglevel = self.env['__cdist_log_level']
                level = int(loglevel)
            except ValueError:
                level = logging.WARNING
        else:
            level = logging.WARNING
        try:
            logging.root.setLevel(level)
        except (ValueError, TypeError):
            # if invalid __cdist_log_level value
            logging.root.setLevel(logging.WARNING)

        self.log = logging.getLogger(self.target_host[0])

    def commandline(self):
        """Parse command line"""

        parser = argparse.ArgumentParser(add_help=False,
                                         argument_default=argparse.SUPPRESS)

        for parameter in self.cdist_type.required_parameters:
            argument = "--" + parameter
            parser.add_argument(argument, dest=parameter, action='store',
                                required=True)
        for parameter in self.cdist_type.required_multiple_parameters:
            argument = "--" + parameter
            parser.add_argument(argument, dest=parameter, action='append',
                                required=True)
        for parameter in self.cdist_type.optional_parameters:
            argument = "--" + parameter
            default = self.cdist_type.parameter_defaults.get(parameter, None)
            parser.add_argument(argument, dest=parameter, action='store',
                                required=False, default=default)
        for parameter in self.cdist_type.optional_multiple_parameters:
            argument = "--" + parameter
            default = DefaultList.create(
                    self.cdist_type.parameter_defaults.get(
                        parameter, None))
            parser.add_argument(argument, dest=parameter, action='append',
                                required=False, default=default)
        for parameter in self.cdist_type.boolean_parameters:
            argument = "--" + parameter
            parser.add_argument(argument, dest=parameter,
                                action='store_const', const='')

        # If not singleton support one positional parameter
        if not self.cdist_type.is_singleton:
            parser.add_argument("object_id", nargs=1)

        # And finally parse/verify parameter
        self.args = parser.parse_args(self.argv[1:])
        self.log.trace('Args: %s' % self.args)

    def init_object(self):
        # Initialize object - and ensure it is not in args
        if self.cdist_type.is_singleton:
            self.object_id = ''
        else:
            self.object_id = self.args.object_id[0]
            del self.args.object_id

        # Instantiate the cdist object we are defining
        self.cdist_object = core.CdistObject(
                self.cdist_type, self.object_base_path, self.object_marker,
                self.object_id)
        lockfname = ('.' + self.cdist_type.name +
                     self.object_id + '_' +
                     self.object_marker + '.lock')
        lockfname = lockfname.replace(os.sep, '_')
        self.flock_path = os.path.join(self.object_base_path, lockfname)

    def setup_object(self):
        # Create object with given parameters
        self.parameters = {}
        for key, value in vars(self.args).items():
            if value is not None:
                self.parameters[key] = value

        if self.cdist_object.exists and 'CDIST_OVERRIDE' not in self.env:
            # Make existing requirements a set so that we can compare it
            # later with new requirements.
            self._existing_reqs = set(self.cdist_object.requirements)
            if self.cdist_object.parameters != self.parameters:
                errmsg = ("Object %s already exists with conflicting "
                          "parameters:\n%s: %s\n%s: %s" % (
                              self.cdist_object.name,
                              " ".join(self.cdist_object.source),
                              self.cdist_object.parameters,
                              self.object_source,
                              self.parameters))
                raise cdist.Error(errmsg)
        else:
            if self.cdist_object.exists:
                self.log.debug(('Object %s override forced with '
                                'CDIST_OVERRIDE'), self.cdist_object.name)
                self.cdist_object.create(True)
            else:
                self.cdist_object.create()
            self.cdist_object.parameters = self.parameters
            # record the created object in typeorder file
            with open(self.typeorder_path, 'a') as typeorderfile:
                print(self.cdist_object.name, file=typeorderfile)

        # Record / Append source
        self.cdist_object.source.append(self.object_source)

    chunk_size = 65536

    def _read_stdin(self):
        return self.stdin.read(self.chunk_size)

    def save_stdin(self):
        """If something is written to stdin, save it in the object as
        $__object/stdin so it can be accessed in manifest and gencode-*
        scripts.
        """
        if not self.stdin.isatty():
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

    def record_requirement(self, requirement):
        """record requirement and return recorded requirement"""

        # Raises an error, if object cannot be created
        try:
            cdist_object = self.cdist_object.object_from_name(requirement)
        except core.cdist_type.InvalidTypeError as e:
            self.log.error(("%s requires object %s, but type %s does not"
                            " exist. Defined at %s" % (
                                self.cdist_object.name,
                                requirement, e.name, self.object_source)))
            raise
        except core.cdist_object.MissingObjectIdError as e:
            self.log.error(("%s requires object %s without object id."
                            " Defined at %s" % (self.cdist_object.name,
                                                requirement,
                                                self.object_source)))
            raise

        self.log.debug("Recording requirement: %s", requirement)

        # Save the sanitised version, not the user supplied one
        # (__file//bar => __file/bar)
        # This ensures pattern matching is done against sanitised list
        self.cdist_object.requirements.append(cdist_object.name)

        return cdist_object.name

    def record_requirements(self):
        """Record requirements."""

        # Inject the predecessor, but not if its an override
        # (this would leed to an circular dependency)
        if ("CDIST_ORDER_DEPENDENCY" in self.env and
                'CDIST_OVERRIDE' not in self.env):
            # load object name created befor this one from typeorder file ...
            with open(self.typeorder_path, 'r') as typecreationfile:
                typecreationorder = typecreationfile.readlines()
                # get the type created before this one ...
                try:
                    lastcreatedtype = typecreationorder[-2].strip()
                    if 'require' in self.env:
                        self.env['require'] += " " + lastcreatedtype
                    else:
                        self.env['require'] = lastcreatedtype
                    self.log.debug(("Injecting require for "
                                    "CDIST_ORDER_DEPENDENCY: %s for %s"),
                                   lastcreatedtype, self.cdist_object.name)
                except IndexError:
                    # if no second last line, we are on the first type,
                    # so do not set a requirement
                    pass

        reqs = set()
        if "require" in self.env:
            requirements = self.env['require']
            self.log.debug("reqs = " + requirements)
            for requirement in requirements.split(" "):
                # Ignore empty fields - probably the only field anyway
                if len(requirement) == 0:
                    continue
                object_name = self.record_requirement(requirement)
                reqs.add(object_name)
        if self._existing_reqs is not None:
            # If object exists then compare existing and new requirements.
            if self._existing_reqs != reqs:
                warnmsg = ("Object {} already exists with requirements:\n"
                           "{}: {}\n"
                           "{}: {}\n"
                           "Dependency resolver could not handle dependencies "
                           "as expected.".format(
                               self.cdist_object.name,
                               " ".join(self.cdist_object.source),
                               self._existing_reqs,
                               self.object_source,
                               reqs
                           ))
                self.log.warning(warnmsg)

    def record_auto_requirements(self):
        """An object shall automatically depend on all objects that it
           defined in it's type manifest.
        """
        # __object_name is the name of the object whose type manifest is
        # currently executed
        __object_name = self.env.get('__object_name', None)
        if __object_name:
            # The object whose type manifest is currently run
            parent = self.cdist_object.object_from_name(__object_name)
            # The object currently being defined
            current_object = self.cdist_object
            # As parent defined current_object it shall automatically
            # depend on it.
            # But only if the user hasn't said otherwise.
            # Must prevent circular dependencies.
            if parent.name not in current_object.requirements:
                parent.autorequire.append(current_object.name)
