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
import re

import cdist
from cdist import core
from cdist import flock
from cdist.core.manifest import Manifest


class MissingRequiredEnvironmentVariableError(cdist.Error):
    def __init__(self, name):
        self.name = name
        self.message = ("Emulator requires the environment variable %s to be "
                        "setup" % self.name)

    def __str__(self):
        return self.message


class DefaultList(list):
    """Helper class to allow default values for optional_multiple parameters.

       @see https://groups.google.com/forum/#!msg/comp.lang.python/sAUvkJEDpRc/RnRymrzJVDYJ  # noqa
    """
    def __copy__(self):
        return []

    @classmethod
    def create(cls, initial=None):
        if initial:
            return cls(initial.split('\n'))


class Emulator:
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

        self.typeorder_dep_path = os.path.join(self.global_path,
                                               Manifest.TYPEORDER_DEP_NAME)
        self.order_dep_state_path = os.path.join(self.global_path,
                                                 Manifest.ORDER_DEP_STATE_NAME)

        self.type_name = os.path.basename(argv[0])
        self.cdist_type = core.CdistType(self.type_base_path, self.type_name)

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
        self.log = logging.getLogger(self.target_host[0])
        try:
            logging.root.setLevel(level)
            self.log.setLevel(level)
        except (ValueError, TypeError):
            # if invalid __cdist_log_level value
            logging.root.setLevel(logging.WARNING)
            self.log.setLevel(logging.WARNING)

        colored_log = self.env.get('__cdist_colored_log', 'false')
        cdist.log.CdistFormatter.USE_COLORS = colored_log == 'true'

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

    def _object_params_in_context(self):
        ''' Get cdist_object parameters dict adopted by context.
        Context consists of cdist_type boolean, optional, required,
        optional_multiple and required_multiple parameters. If parameter
        is multiple parameter then its value is a list.
        This adaptation works on cdist_object.parameters which are read from
        directory based dict where it is unknown what kind of data is in
        file. If there is only one line in the file it is unknown if this
        is a value of required/optional parameter or if it is one value of
        multiple values parameter.
        '''
        params = {}
        if self.cdist_object.exists:
            for param in self.cdist_object.parameters:
                value = ('' if param in self.cdist_type.boolean_parameters
                         else self.cdist_object.parameters[param])
                if ((param in self.cdist_type.required_multiple_parameters or
                     param in self.cdist_type.optional_multiple_parameters) and
                        not isinstance(value, list)):
                    value = [value]
                params[param] = value
        return params

    def setup_object(self):
        # CDIST_ORDER_DEPENDENCY state
        order_dep_on = self._order_dep_on()
        order_dep_defined = "CDIST_ORDER_DEPENDENCY" in self.env
        if not order_dep_defined and order_dep_on:
            self._set_order_dep_state_off()
        if order_dep_defined and not order_dep_on:
            self._set_order_dep_state_on()

        # Create object with given parameters
        self.parameters = {}
        for key, value in vars(self.args).items():
            if value is not None:
                self.parameters[key] = value

        if self.cdist_object.exists and 'CDIST_OVERRIDE' not in self.env:
            obj_params = self._object_params_in_context()
            if obj_params != self.parameters:
                errmsg = ("Object %s already exists with conflicting "
                          "parameters:\n%s: %s\n%s: %s" % (
                              self.cdist_object.name,
                              " ".join(self.cdist_object.source),
                              obj_params,
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
        # Do the following recording even if object exists, but with
        # different requirements.

        # record the created object in typeorder file
        with open(self.typeorder_path, 'a') as typeorderfile:
            print(self.cdist_object.name, file=typeorderfile)
        # record the created object in parent object typeorder file
        __object_name = self.env.get('__object_name', None)
        depname = self.cdist_object.name
        if __object_name:
            parent = self.cdist_object.object_from_name(__object_name)
            parent.typeorder.append(self.cdist_object.name)
            if self._order_dep_on():
                self.log.trace(('[ORDER_DEP] Adding %s to typeorder dep'
                                ' for %s'), depname, parent.name)
                parent.typeorder_dep.append(depname)
        elif self._order_dep_on():
            self.log.trace('[ORDER_DEP] Adding %s to global typeorder dep',
                           depname)
            self._add_typeorder_dep(depname)

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
        except core.cdist_object.MissingObjectIdError:
            self.log.error(("%s requires object %s without object id."
                            " Defined at %s" % (self.cdist_object.name,
                                                requirement,
                                                self.object_source)))
            raise

        self.log.debug("Recording requirement %s for %s",
                       requirement, self.cdist_object.name)

        # Save the sanitised version, not the user supplied one
        # (__file//bar => __file/bar)
        # This ensures pattern matching is done against sanitised list
        self.cdist_object.requirements.append(cdist_object.name)

    def _order_dep_on(self):
        return os.path.exists(self.order_dep_state_path)

    def _set_order_dep_state_on(self):
        self.log.trace('[ORDER_DEP] Setting order dep state on')
        with open(self.order_dep_state_path, 'w'):
            pass

    def _set_order_dep_state_off(self):
        self.log.trace('[ORDER_DEP] Setting order dep state off')
        # remove order dep state file
        try:
            os.remove(self.order_dep_state_path)
        except FileNotFoundError:
            pass
        # remove typeorder dep file
        try:
            os.remove(self.typeorder_dep_path)
        except FileNotFoundError:
            pass

    def _add_typeorder_dep(self, name):
        with open(self.typeorder_dep_path, 'a') as f:
            print(name, file=f)

    def _read_typeorder_dep(self):
        try:
            with open(self.typeorder_dep_path, 'r') as f:
                return f.readlines()
        except FileNotFoundError:
            return []

    def record_requirements(self):
        """Record requirements."""

        order_dep_on = self._order_dep_on()

        # Inject the predecessor, but not if its an override
        # (this would leed to an circular dependency)
        if (order_dep_on and 'CDIST_OVERRIDE' not in self.env):
            try:
                # __object_name is the name of the object whose type
                # manifest is currently executed
                __object_name = self.env.get('__object_name', None)
                # load object name created befor this one from typeorder
                # dep file
                if __object_name:
                    parent = self.cdist_object.object_from_name(
                        __object_name)
                    typeorder = parent.typeorder_dep
                else:
                    typeorder = self._read_typeorder_dep()
                # get the type created before this one
                lastcreatedtype = typeorder[-2].strip()
                if 'require' in self.env:
                    if lastcreatedtype not in self.env['require']:
                        self.env['require'] += " " + lastcreatedtype
                else:
                    self.env['require'] = lastcreatedtype
                self.log.debug(("Injecting require for "
                                "CDIST_ORDER_DEPENDENCY: %s for %s"),
                               lastcreatedtype,
                               self.cdist_object.name)
            except IndexError:
                # if no second last line, we are on the first type,
                # so do not set a requirement
                pass

        if "require" in self.env:
            requirements = self.env['require']
            self.log.debug("reqs = " + requirements)
            for requirement in self._parse_require(requirements):
                # Ignore empty fields - probably the only field anyway
                if len(requirement) == 0:
                    continue
                self.record_requirement(requirement)

    def _parse_require(self, require):
        return re.split(r'[ \t\n]+', require)

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
                self.log.debug("Recording autorequirement %s for %s",
                               current_object.name, parent.name)
                parent.autorequire.append(current_object.name)
