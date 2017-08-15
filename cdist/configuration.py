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
import functools
import cdist.argparse
import re


class Singleton(type):
    instance = None

    def __call__(cls, *args, **kwargs):
        if not cls.instance:
            cls.instance = super(Singleton, cls).__call__(*args, **kwargs)
        return cls.instance


def _convert_option_select(val, option, valid_values):
    if val in valid_values:
        return val
    else:
        raise ValueError("Invalid {} value: {}.".format(option, val))


def _convert_conf_dir(val):
    vals = re.split(r'(?<!\\):', val)
    vals = [x for x in vals if x]
    if vals:
        return vals
    else:
        return None


def _convert_verbosity(val):
    val = _convert_option_select(
        val, 'verbosity', Configuration.VERBOSITY_VALUES)
    if val == 'QUIET':
        return cdist.argparse.VERBOSE_OFF
    else:
        name = 'VERBOSE_' + val
        verbose = getattr(cdist.argparse, name)
        return verbose


def _convert_archiving(val):
    val = _convert_option_select(
        val, 'archiving', Configuration.ARCHIVING_VALUES)
    if val == 'none':
        return None
    else:
        return val


class Configuration(metaclass=Singleton):
    global_config_file = os.path.join('/', 'etc', 'cdist.cfg', )
    local_config_file = os.path.join(os.path.expanduser('~'),
                                     '.cdist', 'cdist.cfg', )
    default_config_files = (global_config_file, local_config_file, )

    VERBOSITY_VALUES = (
        'ERROR', 'WARNING', 'INFO', 'VERBOSE', 'DEBUG', 'TRACE', 'QUIET',
    )
    ARCHIVING_VALUES = (
        'tar', 'tgz', 'tbz2', 'txz', 'none',
    )

    CONFIG_FILE_OPTIONS = {
        'GLOBAL': {
            'beta': 'boolean',
            'local_shell': str,
            'remote_shell': str,
            'cache_path_pattern': str,
            'conf_dir': _convert_conf_dir,
            'init_manifest': str,
            'out_path': str,
            'remote_out_path': str,
            'remote_copy': str,
            'remote_exec': str,
            'inventory_dir': str,
            'jobs': int,
            'parallel': int,
            'verbosity': _convert_verbosity,
            'archiving': _convert_archiving,
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
    }
    BOOL_ENV_VAR_OPTIONS = ('CDIST_BETA', )
    ARG_OPTION_MAPPING = {
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
    }
    ADJUST_ARG_OPTION_MAPPING = {
        'beta': 'beta',
        'cache_path_pattern': 'cache_path_pattern',
        'conf_dir': 'conf_dir',
        'init_manifest': 'manifest',
        'out_path': 'out_path',
        'remote_out_path': 'remote_out_path',
        'remote_copy': 'remote_copy',
        'remote_exec': 'remote_exec',
        'inventory_dir': 'inventory_dir',
        'jobs': 'jobs',
        'parallel': 'parallel',
        'verbosity': 'verbose',
        'archiving': 'use_archiving',
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

    def __init__(self, args, env=os.environ,
                 config_files=default_config_files):
        self.args = self._convert_args(args)
        self.env = env
        self.config_files = config_files
        self.config = self._get_config()

    def get_config(self, section=None):
        if section is None:
            return self.config
        if section in self.config:
            return self.config[section]
        raise ValueError('Unknown section: {}'.format(section))

    def adjust_args(self, args, section='GLOBAL'):
        args_dict = self._convert_args(args)
        cfg = self.get_config(section)
        for option in self.ADJUST_ARG_OPTION_MAPPING:
            if option in cfg:
                arg_opt = self.ADJUST_ARG_OPTION_MAPPING[option]
                if option == 'verbosity' and cfg[option] == 'QUIET':
                    setattr(args, 'quiet', True)
                else:
                    setattr(args, arg_opt, cfg[option])

    def _convert_value(self, val, option, converter):
        try:
            newval = converter(val)
        except:
            raise ValueError("Invalid {} value: {}.".format(option, val))
        if not isinstance(newval, str) or newval:
            return newval
        else:
            return None

    def _read_config_file(self, files):
        config_parser = configparser.ConfigParser()
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
                converter = self.CONFIG_FILE_OPTIONS[section][option]
                if converter == 'boolean':
                    newval = config_parser.getboolean(section, option)
                else:
                    val = config_parser[section][option]
                    newval = self._convert_value(val, option, converter)
                d[section][option] = newval
        return d

    def _read_env_var_config(self, env):
        d = dict()
        for option in self.ENV_VAR_OPTION_MAPPING:
            if option in env:
                dst_option = self.ENV_VAR_OPTION_MAPPING[option]
                if option in self.BOOL_ENV_VAR_OPTIONS:
                    d[dst_option] = True
                elif dst_option == 'conf_dir':
                    d[dst_option] = _convert_conf_dir(env[option])
                else:
                    d[dst_option] = env[option]
        return d

    def _read_args_config(self, args):
        d = dict()
        for option in self.ARG_OPTION_MAPPING:
            if option in args:
                dst_option = self.ARG_OPTION_MAPPING[option]
                d[dst_option] = args[option]
        return d

    def _update_config_dict(self, config, newconfig):
        for section in newconfig:
            self._update_config_dict_section(
                section, config, newconfig[section])

    def _update_config_dict_section(self, section, config, newconfig):
        if section not in config:
            config[section] = dict()
        for option in newconfig:
            val = newconfig[option]
            if option == 'conf_dir':
                newval = []
                if option in config[section] and config[section][option]:
                    newval.extend(config[section][option])
                if newconfig[option]:
                    newval.extend(newconfig[option])
            else:
                newval = val
            config[section][option] = newval

    def _translate_values(self, config):
        for section in config:
            x = config[section]
            for option in x:
                if option in ('jobs', 'parallel', ):
                    if x[option] == -1:
                        import multiprocessing
                        x[option] = multiprocessing.cpu_count()

    def _get_config(self):
        # global config file
        # local config file
        config = self._read_config_file(self.config_files)
        # default empty config if needed
        if not config:
            config['GLOBAL'] = dict()
        # environment variable
        newconfig = self._read_env_var_config(self.env)
        for section in config:
            self._update_config_dict_section(section, config, newconfig)
        # command line config file
        if (self.args and 'config_file' in self.args and
                self.args['config_file']):
            newconfig = self._read_config_file(self.args['config_file'])
            self._update_config_dict(config, newconfig)
        # command line
        if self.args:
            newconfig = self._read_args_config(self.args)
            for section in config:
                self._update_config_dict_section(section, config, newconfig)
        self._translate_values(config)
        return config
