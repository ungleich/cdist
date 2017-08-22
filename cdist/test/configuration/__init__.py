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
import cdist.configuration as cc
import os.path as op
import argparse
from cdist import test
import cdist.argparse as cap


my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')


class ConfigurationTestCase(test.CdistTestCase):

    def setUp(self):
        # Create test config file.
        config = configparser.ConfigParser()
        config['GLOBAL'] = {
            'beta': 'off',
            'local_shell': '/bin/sh',
            'remote_shell': '/bin/sh',
            'inventory_dir': '',
            'cache_path_pattern': '',
            'conf_dir': '',
            'init_manifest': '',
            'out_path': '',
            'remote_out_path': '',
            'remote_copy': '',
            'remote_exec': '',
            'jobs': '0',
            'parallel': '-1',
            'verbosity': 'INFO',
            'archiving': 'none',
        }
        config_custom = configparser.ConfigParser()
        config_custom['GLOBAL'] = {
            'parallel': '4',
            'archiving': 'txz',
        }

        self.expected_config_dict = {
            'GLOBAL': {
                'beta': False,
                'local_shell': '/bin/sh',
                'remote_shell': '/bin/sh',
                'inventory_dir': None,
                'cache_path_pattern': None,
                'conf_dir': None,
                'init_manifest': None,
                'out_path': None,
                'remote_out_path': None,
                'remote_copy': None,
                'remote_exec': None,
                'jobs': 0,
                'parallel': -1,
                'verbosity': cap.VERBOSE_INFO,
                'archiving': None,
            },
        }

        self.config_file = os.path.join(fixtures, 'cdist.cfg')
        with open(self.config_file, 'w') as f:
            config.write(f)

        self.custom_config_file = os.path.join(fixtures, 'cdist_custom.cfg')
        with open(self.custom_config_file, 'w') as f:
            config_custom.write(f)

        config['TEST'] = {}
        self.invalid_config_file1 = os.path.join(fixtures,
                                                 'cdist_invalid1.cfg')
        with open(self.invalid_config_file1, 'w') as f:
            config.write(f)

        del config['TEST']
        config['GLOBAL']['test'] = 'test'
        self.invalid_config_file2 = os.path.join(fixtures,
                                                 'cdist_invalid2.cfg')
        with open(self.invalid_config_file2, 'w') as f:
            config.write(f)

        del config['GLOBAL']['test']
        config['GLOBAL']['archiving'] = 'zip'
        self.invalid_config_file3 = os.path.join(fixtures,
                                                 'cdist_invalid3.cfg')
        with open(self.invalid_config_file3, 'w') as f:
            config.write(f)

        self.maxDiff = None

    def tearDown(self):
        os.remove(self.config_file)
        os.remove(self.custom_config_file)
        os.remove(self.invalid_config_file1)
        os.remove(self.invalid_config_file2)
        os.remove(self.invalid_config_file3)

    def test_singleton(self):
        x = cc.Configuration(None)
        args = argparse.Namespace()
        args.a = 'a'
        y = cc.Configuration()
        self.assertIs(x, y)

    def test_convert_option_select(self):
        valid_values = ('spam', 'eggs', )
        val = 'spam'
        rv = cc._convert_option_select(val, 'test', valid_values)
        self.assertEqual(val, rv)
        val = 'spamandeggs'
        with self.assertRaises(ValueError):
            cc._convert_option_select(val, 'test', valid_values)

    def test_convert_conf_dir(self):
        val = '/usr/local/cdist:~/.cdist:~/dot-cdist'
        expected = ['/usr/local/cdist', '~/.cdist', '~/dot-cdist', ]
        rv = cc._convert_conf_dir(val)
        self.assertEqual(rv, expected)

    def test_convert_verbosity(self):
        for val in cc.Configuration.VERBOSITY_VALUES:
            if val == 'QUIET':
                expected = cap.VERBOSE_OFF
            else:
                expected = getattr(cap, 'VERBOSE_' + val)
            rv = cc._convert_verbosity(val)
            self.assertEqual(rv, expected)
        with self.assertRaises(ValueError):
            val = 'test'
            cc._convert_verbosity(val)

    def test_read_config_file(self):
        config = cc.Configuration(None, env={}, config_files=())
        d = config._read_config_file(self.config_file)
        self.assertEqual(d, self.expected_config_dict)

        for x in range(1, 4):
            config_file = getattr(self, 'invalid_config_file' + str(x))
            with self.assertRaises(ValueError):
                config._read_config_file(config_file)

    def test_read_env_var_config(self):
        config = cc.Configuration(None, env={}, config_files=())
        env = {
            'a': 'a',
            'CDIST_BETA': '1',
            'CDIST_PATH': '/usr/local/cdist:~/.cdist',
        }
        expected = {
            'beta': True,
            'conf_dir': ['/usr/local/cdist', '~/.cdist', ],
        }
        d = config._read_env_var_config(env)
        self.assertEqual(d, expected)

        del env['CDIST_BETA']
        del expected['beta']
        d = config._read_env_var_config(env)
        self.assertEqual(d, expected)

    def test_read_args_config(self):
        config = cc.Configuration(None, env={}, config_files=())
        args = argparse.Namespace()
        args.beta = False
        args.conf_dir = '/usr/local/cdist:~/.cdist'
        args.verbose = 3
        args.tag = 'test'

        expected = {
            'beta': False,
            'conf_dir': '/usr/local/cdist:~/.cdist',
            'verbosity': 3,
        }
        args_dict = vars(args)
        d = config._read_args_config(args_dict)
        self.assertEqual(d, expected)
        self.assertNotEqual(d, args_dict)

    def test_update_config_dict(self):
        config = {
            'GLOBAL': {
                'conf_dir': ['/usr/local/cdist', ],
                'parallel': -1,
            },
        }
        newconfig = {
            'GLOBAL': {
                'conf_dir': ['~/.cdist', ],
                'parallel': 2,
                'local_shell': '/usr/local/bin/sh',
            },
        }
        expected = {
            'GLOBAL': {
                'conf_dir': ['/usr/local/cdist', '~/.cdist', ],
                'parallel': 2,
                'local_shell': '/usr/local/bin/sh',
            },
        }
        configuration = cc.Configuration(None, env={}, config_files=())
        configuration._update_config_dict(config, newconfig)
        self.assertEqual(config, expected)

    def test_update_config_dict_section(self):
        config = {
            'GLOBAL': {
                'conf_dir': ['/usr/local/cdist', ],
                'parallel': -1,
            },
        }
        newconfig = {
            'conf_dir': ['~/.cdist', ],
            'parallel': 2,
            'local_shell': '/usr/local/bin/sh',
        }
        expected = {
            'GLOBAL': {
                'conf_dir': ['/usr/local/cdist', '~/.cdist', ],
                'parallel': 2,
                'local_shell': '/usr/local/bin/sh',
            },
        }
        configuration = cc.Configuration(None, env={}, config_files=())
        configuration._update_config_dict_section('GLOBAL', config, newconfig)
        self.assertEqual(config, expected)

    def test_translate_values(self):
        import multiprocessing

        config = {
            'GLOBAL': {
                'beta': 'on',
                'jobs': -1,
                'parallel': 0,
            },
        }
        expected = {
            'GLOBAL': {
                'beta': 'on',
                'jobs': multiprocessing.cpu_count(),
                'parallel': 0,
            },
        }
        configuration = cc.Configuration(None, env={}, config_files=())
        d = dict(config)
        configuration._translate_values(d)
        self.assertEqual(d, expected)

        config['GLOBAL']['parallel'] = -1
        expected['GLOBAL']['parallel'] = multiprocessing.cpu_count()
        configuration = cc.Configuration(None, env={}, config_files=())
        d = dict(config)
        configuration._translate_values(d)
        self.assertEqual(d, expected)

    def test_get_config_and_configured_args(self):
        args = argparse.Namespace()
        args.jobs = 8
        args.dry_run = True
        args.config_file = self.custom_config_file

        env = {
            'CDIST_BETA': '1',
            'CDIST_PATH': '/usr/local/cdist:~/.cdist',
            'CDIST_REMOTE_SHELL': '/usr/local/bin/sh',
            'test': 'test',
        }

        expected = dict(self.expected_config_dict)
        expected['GLOBAL']['conf_dir'] = ['/usr/local/cdist', '~/.cdist', ]
        expected['GLOBAL']['remote_shell'] = '/usr/local/bin/sh'
        expected['GLOBAL']['beta'] = True
        expected['GLOBAL']['jobs'] = 8
        expected['GLOBAL']['parallel'] = 4
        expected['GLOBAL']['archiving'] = 'txz'

        config_files = (self.config_file, )

        configuration = cc.Configuration(args, env=env,
                                         config_files=config_files)
        self.assertIsNotNone(configuration.args)
        self.assertIsNotNone(configuration.env)
        self.assertIsNotNone(configuration.config_files)
        self.assertEqual(configuration.config, expected)

        got_config = configuration.get_config()
        self.assertEqual(got_config, expected)

        global_config = configuration.get_config('GLOBAL')
        self.assertEqual(global_config, expected['GLOBAL'])

        args = argparse.Namespace()
        self.assertEqual(vars(args), {})
        args = configuration.get_args()
        dargs = vars(args)
        expected_args = {
            'beta': True,
            'inventory_dir': None,
            'cache_path_pattern': None,
            'conf_dir': ['/usr/local/cdist', '~/.cdist', ],
            'manifest': None,
            'out_path': None,
            'remote_out_path': None,
            'remote_copy': None,
            'remote_exec': None,
            'jobs': 8,
            'parallel': 4,
            'verbose': cap.VERBOSE_INFO,
            'use_archiving': 'txz',
            'dry_run': True,
            'config_file': self.custom_config_file,
        }

        self.assertEqual(dargs, expected_args)


if __name__ == "__main__":
    import unittest

    unittest.main()
