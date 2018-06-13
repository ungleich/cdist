# -*- coding: utf-8 -*-
#
# 2017 Darko Poljak (darko.poljak at gmail.com)
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


import configparser
import os
import cdist
import cdist.argparse
import re
import multiprocessing
import logging


class Singleton(type):
    instance = None

    def __call__(cls, *args, **kwargs):
        if 'singleton' in kwargs and not kwargs['singleton']:
            return super(Singleton, cls).__call__(*args, **kwargs)
        else:
            if not cls.instance:
                cls.instance = super(Singleton, cls).__call__(*args, **kwargs)
            return cls.instance


_VERBOSITY_VALUES = (
    'ERROR', 'WARNING', 'INFO', 'VERBOSE', 'DEBUG', 'TRACE', 'OFF',
)
_ARCHIVING_VALUES = (
    'tar', 'tgz', 'tbz2', 'txz', 'none',
)


class OptionBase:
    def __init__(self, name):
        self.name = name

    def get_converter(self, *args, **kwargs):
        raise NotImplementedError('Subclass should implement this method')

    def translate(self, val):
        return val

    def update_value(self, currval, newval, update_appends=False):
        '''Update current option value currval with new option value newval.
        If update_appends is True and if currval and newval are lists then
        resulting list contains all values in currval plus all values in
        newval. Otherwise, newval is returned.
        '''
        if (isinstance(currval, list) and isinstance(newval, list) and
                update_appends):
            rv = []
            if currval:
                rv.extend(currval)
            if newval:
                rv.extend(newval)
            if not rv:
                rv = None
            return rv
        else:
            return newval

    def should_override(self, currval, newval):
        return True


class StringOption(OptionBase):
    def __init__(self, name):
        super().__init__(name)

    def get_converter(self):
        def string_converter(val):
            return self.translate(str(val))
        return string_converter

    def translate(self, val):
        if val:
            return val
        else:
            return None


class BooleanOption(OptionBase):
    BOOLEAN_STATES = configparser.ConfigParser.BOOLEAN_STATES

    # If default_overrides is False then previous config value will not be
    # overriden with default_value.
    def __init__(self, name, default_overrides=True, default_value=True):
        super().__init__(name)
        self.default_overrides = default_overrides
        self.default_value = default_value

    def get_converter(self):
        def boolean_converter(val):
            v = val.lower()
            if v not in self.BOOLEAN_STATES:
                raise ValueError('Invalid {} boolean value: {}'.format(
                    self.name, val))
            return self.translate(v)
        return boolean_converter

    def translate(self, val):
        return self.BOOLEAN_STATES[val]

    def should_override(self, currval, newval):
        if not self.default_overrides:
            return newval != self.default_value
        return True


class IntOption(OptionBase):
    def __init__(self, name):
        super().__init__(name)

    def get_converter(self):
        def int_converter(val):
            return self.translate(int(val))
        return int_converter


class LowerBoundIntOption(IntOption):
    def __init__(self, name, lower_bound):
        super().__init__(name)
        self.lower_bound = lower_bound

    def get_converter(self):
        def lower_bound_converter(val):
            converted = super(LowerBoundIntOption, self).get_converter()(val)
            if converted < self.lower_bound:
                raise ValueError("Invalid {} value: {} < {}".format(
                    self.name, val, self.lower_bound))
            return converted
        return lower_bound_converter


class SpecialCasesLowerBoundIntOption(LowerBoundIntOption):
    def __init__(self, name, lower_bound, special_cases_mapping):
        super().__init__(name, lower_bound)
        self.special_cases_mapping = special_cases_mapping

    def translate(self, val):
        if val in self.special_cases_mapping:
            return self.special_cases_mapping[val]
        else:
            return val


class JobsOption(SpecialCasesLowerBoundIntOption):
    def __init__(self, name):
        super().__init__(name, -1, {-1: multiprocessing.cpu_count()})


class SelectOption(OptionBase):
    def __init__(self, name, valid_values):
        super().__init__(name)
        self.valid_values = valid_values

    def get_converter(self):
        def select_converter(val):
            if val in self.valid_values:
                return self.translate(val)
            else:
                raise ValueError("Invalid {} value: {}.".format(
                    self.name, val))
        return select_converter


class VerbosityOption(SelectOption):
    def __init__(self):
        super().__init__('verbosity', _VERBOSITY_VALUES)

    def translate(self, val):
        name = 'VERBOSE_' + val
        verbose = getattr(cdist.argparse, name)
        return verbose


class DelimitedValuesOption(OptionBase):
    def __init__(self, name, delimiter):
        super().__init__(name)
        self.delimiter = delimiter

    def get_converter(self):
        def delimited_values_converter(val):
            vals = re.split(r'(?<!\\)' + self.delimiter, val)
            vals = [x for x in vals if x]
            return self.translate(vals)
        return delimited_values_converter

    def translate(self, val):
        if val:
            return val
        else:
            return None


class ConfDirOption(DelimitedValuesOption):
    def __init__(self):
        super().__init__('conf_dir', os.pathsep)


class ArchivingOption(SelectOption):
    def __init__(self):
        super().__init__('archiving', _ARCHIVING_VALUES)

    def translate(self, val):
        if val == 'none':
            return None
        else:
            return val


class LogLevelOption(OptionBase):
    def __init__(self):
        super().__init__('__cdist_log_level')

    def get_converter(self):
        def log_level_converter(val):
            try:
                val = logging.getLevelName(int(val))
                return self.translate(val)
            except (ValueError, AttributeError):
                raise ValueError("Invalid {} value: {}.".format(
                    self.name, val))
        return log_level_converter

    def translate(self, val):
        return VerbosityOption().translate(val)


_ARG_OPTION_MAPPING = {
    'beta': 'beta',
    'cache_path_pattern': 'cache_path_pattern',
    'conf_dir': 'conf_dir',
    'manifest': 'init_manifest',
    'out_path': 'out_path',
    'remote_out_path': 'remote_out_path',
    'remote_copy': 'remote_copy',
    'remote_exec': 'remote_exec',
    'inventory_dir': 'inventory_dir',
    'jobs': 'jobs',
    'parallel': 'parallel',
    'verbose': 'verbosity',
    'use_archiving': 'archiving',
    'save_output_streams': 'save_output_streams',
}


class Configuration(metaclass=Singleton):
    _config_basename = 'cdist.cfg'
    _global_config_file = os.path.join('/', 'etc', _config_basename, )
    _local_config_file = os.path.join(os.path.expanduser('~'),
                                      '.' + _config_basename, )
    if (not (os.path.exists(_local_config_file) and
             os.path.isfile(_local_config_file))):
        _local_config_file = os.path.join(
            os.environ.get('XDG_CONFIG_HOME',
                           os.path.expanduser('~/.config/cdist')),
            _config_basename)
    _dist_config_file = os.path.join(
        os.path.abspath(os.path.join(os.path.dirname(cdist.__file__), "conf")),
        'cdist.cfg')
    default_config_files = (_global_config_file, _dist_config_file,
                            _local_config_file, )
    ENV_VAR_CONFIG_FILE = 'CDIST_CONFIG_FILE'

    VERBOSITY_VALUES = _VERBOSITY_VALUES
    ARCHIVING_VALUES = _ARCHIVING_VALUES

    CONFIG_FILE_OPTIONS = {
        'GLOBAL': {
            'beta': BooleanOption('beta'),
            'local_shell': StringOption('local_shell'),
            'remote_shell': StringOption('remote_shell'),
            'cache_path_pattern': StringOption('cache_path_pattern'),
            'conf_dir': ConfDirOption(),
            'init_manifest': StringOption('init_manifest'),
            'out_path': StringOption('out_path'),
            'remote_out_path': StringOption('remote_out_path'),
            'remote_copy': StringOption('remote_copy'),
            'remote_exec': StringOption('remote_exec'),
            'inventory_dir': StringOption('inventory_dir'),
            'jobs': JobsOption('jobs'),
            'parallel': JobsOption('parallel'),
            'verbosity': VerbosityOption(),
            'archiving': ArchivingOption(),
            'save_output_streams': BooleanOption('save_output_streams',
                                                 default_overrides=False),
        },
    }

    ENV_VAR_OPTION_MAPPING = {
        'CDIST_BETA': 'beta',
        'CDIST_PATH': 'conf_dir',
        'CDIST_LOCAL_SHELL': 'local_shell',
        'CDIST_REMOTE_SHELL': 'remote_shell',
        'CDIST_REMOTE_EXEC': 'remote_exec',
        'CDIST_REMOTE_COPY': 'remote_copy',
        'CDIST_INVENTORY_DIR': 'inventory_dir',
        'CDIST_CACHE_PATH_PATTERN': 'cache_path_pattern',
        '__cdist_log_level': 'verbosity',
    }
    ENV_VAR_BOOLEAN_OPTIONS = ('CDIST_BETA', )
    ENV_VAR_OPTIONS = {
        '__cdist_log_level': LogLevelOption(),
    }

    ARG_OPTION_MAPPING = _ARG_OPTION_MAPPING
    ADJUST_ARG_OPTION_MAPPING = {
       _ARG_OPTION_MAPPING[key]: key for key in _ARG_OPTION_MAPPING
    }
    REQUIRED_DEFAULT_CONFIG_VALUES = {
        'GLOBAL': {
            'verbosity': 0,
        },
    }

    def _convert_args(self, args):
        if args:
            if hasattr(args, '__dict__'):
                return vars(args)
            else:
                raise ValueError(
                    'args parameter must be have __dict__ attribute')
        else:
            return None

    def __init__(self, command_line_args, env=os.environ,
                 config_files=default_config_files, singleton=True):
        self.command_line_args = command_line_args
        self.args = self._convert_args(command_line_args)
        if env is None:
            self.env = {}
        else:
            self.env = env
        self.config_files = config_files
        self.config = self._get_config()

    def get_config(self, section=None):
        if section is None:
            return self.config
        if section in self.config:
            return self.config[section]
        raise ValueError('Unknown section: {}'.format(section))

    def _get_args_name_value(self, arg_name, val):
        if arg_name == 'verbosity' and val == 'OFF':
            name = 'quiet'
            rv = True
        else:
            name = arg_name
            rv = val
        return (name, rv)

    def get_args(self, section='GLOBAL'):
        args = self.command_line_args
        cfg = self.get_config(section)
        for option in self.ADJUST_ARG_OPTION_MAPPING:
            if option in cfg:
                arg_name = self.ADJUST_ARG_OPTION_MAPPING[option]
                val = cfg[option]
                name, val = self._get_args_name_value(arg_name, val)
                setattr(args, name, val)
        return args

    def _read_config_file(self, files):
        config_parser = configparser.ConfigParser(interpolation=None)
        config_parser.read(files)
        d = dict()
        for section in config_parser.sections():
            if section not in self.CONFIG_FILE_OPTIONS:
                raise ValueError("Invalid section: {}.".format(section))
            if section not in d:
                d[section] = dict()

            for option in config_parser[section]:
                if option not in self.CONFIG_FILE_OPTIONS[section]:
                    raise ValueError("Invalid option: {}.".format(option))

                option_object = self.CONFIG_FILE_OPTIONS[section][option]
                converter = option_object.get_converter()
                val = config_parser[section][option]
                newval = converter(val)
                d[section][option] = newval
        return d

    def _read_env_var_config(self, env, section):
        d = dict()
        for option in self.ENV_VAR_OPTION_MAPPING:
            if option in env:
                dst_opt = self.ENV_VAR_OPTION_MAPPING[option]
                if option in self.ENV_VAR_BOOLEAN_OPTIONS:
                    d[dst_opt] = True
                else:
                    if option in self.ENV_VAR_OPTIONS:
                        opt = self.ENV_VAR_OPTIONS[option]
                    else:
                        opt = self.CONFIG_FILE_OPTIONS[section][dst_opt]
                    converter = opt.get_converter()
                    val = env[option]
                    newval = converter(val)
                    d[dst_opt] = newval
        return d

    def _read_args_config(self, args):
        d = dict()
        for option in self.ARG_OPTION_MAPPING:
            if option in args:
                dst_opt = self.ARG_OPTION_MAPPING[option]
                option_object = self.CONFIG_FILE_OPTIONS['GLOBAL'][dst_opt]
                # If option is in args.
                # Also if it is boolean but only if not None - this allows
                # False to override True.
                if (args[option] or
                    (isinstance(option_object, BooleanOption) and
                        args[option] is not None)):
                    d[dst_opt] = args[option]
        return d

    def _update_config_dict(self, config, newconfig, update_appends=False):
        for section in newconfig:
            self._update_config_dict_section(
                section, config, newconfig[section], update_appends)

    def _update_config_dict_section(self, section, config, newconfig,
                                    update_appends=False):
        if section not in config:
            config[section] = dict()
        for option in newconfig:
            newval = newconfig[option]
            if option in config[section]:
                currval = config[section][option]
            else:
                currval = None
            option_object = self.CONFIG_FILE_OPTIONS[section][option]
            if option_object.should_override(currval, newval):
                config[section][option] = option_object.update_value(
                    currval, newval, update_appends)

    def _update_defaults_for_unset(self, config):
        defaults = self.REQUIRED_DEFAULT_CONFIG_VALUES

        for section in defaults:
            section_values = defaults[section]
            for option in section_values:
                if option not in config[section]:
                    config[section][option] = section_values[option]

    def _get_config(self):
        # global config file
        # local config file
        config = self._read_config_file(self.config_files)
        # default empty config if needed
        if not config:
            config['GLOBAL'] = dict()
        # environment variables
        newconfig = self._read_env_var_config(self.env, 'GLOBAL')
        for section in config:
            self._update_config_dict_section(section, config, newconfig)
        # config file in CDIST_CONFIG_FILE env var
        config_file = os.environ.get(self.ENV_VAR_CONFIG_FILE, None)
        if config_file:
            newconfig = self._read_config_file(config_file)
            self._update_config_dict(config, newconfig)
        # command line config file
        if (self.args and 'config_file' in self.args and
                self.args['config_file']):
            newconfig = self._read_config_file(self.args['config_file'])
            self._update_config_dict(config, newconfig)
        # command line
        if self.args:
            newconfig = self._read_args_config(self.args)
            for section in config:
                self._update_config_dict_section(section, config, newconfig,
                                                 update_appends=True)
        self._update_defaults_for_unset(config)
        return config
