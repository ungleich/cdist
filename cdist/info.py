# -*- coding: utf-8 -*-
#
# 2019-2020 Darko Poljak (darko.poljak at gmail.com)
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

import cdist
import cdist.configuration
import cdist.core
import cdist.exec.util as util
import os
import glob
import fnmatch


class Info:
    def __init__(self, conf_dirs, args):
        self.conf_dirs = conf_dirs
        self.all = args.all
        self.display_global_explorers = args.global_explorers
        self.display_types = args.types
        if not self.display_global_explorers and not self.display_types:
            self.all = True
        self.fixed_string = args.fixed_string
        self._setup_glob_pattern(args.pattern)
        self.full = args.full

    def _setup_glob_pattern(self, pattern):
        if pattern is None:
            self.glob_pattern = '*'
        elif ('?' in pattern or '*' in pattern or '[' in pattern or
              self.fixed_string):
            self.glob_pattern = pattern
        else:
            self.glob_pattern = '*' + pattern + '*'

    @classmethod
    def commandline(cls, args):
        conf_dirs = util.resolve_conf_dirs_from_config_and_args(args)
        c = cls(conf_dirs, args)
        c.run()

    def _get_global_explorers(self, conf_path):
        rv = []
        global_explorer_path = os.path.join(conf_path, "explorer",
                                            self.glob_pattern)
        if self.fixed_string:
            if os.path.exists(global_explorer_path):
                rv.append(global_explorer_path)
        else:
            for explorer in glob.glob(global_explorer_path):
                rv.append(explorer)
        return rv

    def _should_display_type(self, dir_entry):
        if not dir_entry.is_dir():
            return False
        if self.glob_pattern is None:
            return True
        if self.fixed_string:
            return dir_entry.name == self.glob_pattern
        else:
            return fnmatch.fnmatch(dir_entry.name, self.glob_pattern)

    def _get_types(self, conf_path):
        rv = []
        types_path = os.path.join(conf_path, "type")
        if not os.path.exists(types_path):
            return rv
        with os.scandir(types_path) as it:
            for entry in it:
                if self._should_display_type(entry):
                    rv.append(entry.path)
        return rv

    def _display_details(self, title, details, default_values=None,
                         deprecated=None):
        if not details:
            return
        if isinstance(details, bool):
            print("\t{}: {}".format(title, 'yes' if details else 'no'))
        elif isinstance(details, str):
            print("\t{}: {}".format(title, details))
        elif isinstance(details, list):
            dv = dict(default_values) if default_values else {}
            dp = dict(deprecated) if deprecated else {}

            print("\t{}:".format(title))
            for x in sorted(details):
                print("\t\t{}".format(x), end='')
                has_default = x in dv
                is_deprecated = x in dp
                need_comma = False
                if has_default or is_deprecated:
                    print(" (", end='')
                if has_default:
                    print("default: {}".format(dv[x]), end='')
                    need_comma = True
                if is_deprecated:
                    print("{}deprecated".format(', ' if need_comma else ''),
                          end='')
                if has_default or is_deprecated:
                    print(")", end='')
                print()

    def _display_type_parameters(self, cdist_type):
        self._display_details("required parameters",
                              cdist_type.required_parameters,
                              default_values=cdist_type.parameter_defaults,
                              deprecated=cdist_type.deprecated_parameters)
        self._display_details("required multiple parameters",
                              cdist_type.required_multiple_parameters,
                              default_values=cdist_type.parameter_defaults,
                              deprecated=cdist_type.deprecated_parameters)
        self._display_details("optional parameters",
                              cdist_type.optional_parameters,
                              default_values=cdist_type.parameter_defaults,
                              deprecated=cdist_type.deprecated_parameters)
        self._display_details("optional multiple parameters",
                              cdist_type.optional_multiple_parameters,
                              default_values=cdist_type.parameter_defaults,
                              deprecated=cdist_type.deprecated_parameters)
        self._display_details("boolean parameters",
                              cdist_type.boolean_parameters,
                              default_values=cdist_type.parameter_defaults,
                              deprecated=cdist_type.deprecated_parameters)

    def _display_type_characteristics(self, cdist_type):
        characteristics = []
        if cdist_type.is_install:
            characteristics.append('install')
        else:
            characteristics.append('config')
        if cdist_type.is_singleton:
            characteristics.append('singleton')
        if cdist_type.is_nonparallel:
            characteristics.append('nonparallel')
        else:
            characteristics.append('parallel')
        if cdist_type.deprecated is not None:
            characteristics.append('deprecated')
        print("\t{}".format(', '.join(characteristics)))

    def _display_type_details(self, type_path):
        dirname, basename = os.path.split(type_path)
        cdist_type = cdist.core.CdistType(dirname, basename)

        self._display_type_characteristics(cdist_type)
        self._display_type_parameters(cdist_type)

    def run(self):
        rv = []
        for cp in self.conf_dirs:
            conf_path = os.path.expanduser(cp)
            if self.all or self.display_global_explorers:
                rv.extend((x, 'E', ) for x in self._get_global_explorers(
                    conf_path))
            if self.all or self.display_types:
                rv.extend((x, 'T', ) for x in self._get_types(conf_path))
        rv = sorted(rv, key=lambda x: x[0])
        for x, t in rv:
            print(x)
            if self.full and t == 'T':
                self._display_type_details(x)
