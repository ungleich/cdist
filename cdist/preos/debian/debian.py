#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2016 Darko Poljak (darko.poljak at ungleich.ch)
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
import cdist.config
import cdist.core
import cdist.preos
import argparse
import cdist.argparse
import logging
import os
import subprocess


class Debian(object):
    preos_name = 'debian'

    @classmethod
    def commandline(cls, argv):
        log = logging.getLogger(cls.__name__)

        files_dir = os.path.join(os.path.dirname(__file__), "files")
        default_remote_exec = os.path.join(files_dir, "remote-exec.sh")
        default_remote_copy = os.path.join(files_dir, "remote-copy.sh")
        default_init_manifest = os.path.join(
            files_dir, "init-manifest-{}".format(cls.preos_name))
        cmd = os.path.join(files_dir, "code")

        cdist_parser = cdist.argparse.get_parsers()
        parser = argparse.ArgumentParser(
                prog='cdist preos {}'.format(cls.preos_name),
                parents=[cdist_parser['loglevel'], cdist_parser['beta']])
        parser.add_argument('target_dir', nargs=1,
                            help="target directory")
        parser.add_argument('-a', '--arch', help='target architecture',
                            dest='arch', default="amd64")
        parser.add_argument(
            '-B', '--bootstrap',
            help='do bootstrap step',
            dest='bootstrap', action='store_true', default=False)
        parser.add_argument(
            '-C', '--configure',
            help='do configure step',
            dest='configure', action='store_true', default=False)
        parser.add_argument(
            '-c', '--cdist-params',
            help='parameters that will be passed to cdist config',
            dest='cdist_params', default="-v")
        parser.add_argument(
            '-e', '--remote-exec',
            help='remote exec that cdist config will use',
            dest='remote_exec', default=default_remote_exec)
        parser.add_argument(
            '-i', '--init-manifest',
            help='init manifest that cdist config will use',
            dest='manifest', default=default_init_manifest)
        parser.add_argument(
            '-k', '--keyfile', nargs="*",
            help='ssh key files that will be added to cdist config',
            dest='keyfile')
        parser.add_argument(
            '-m', '--mirror',
            help='use specified mirror',
            dest='mirror')
        parser.add_argument('-p', '--pxe-boot-dir', help='PXE boot directory',
                            dest='pxe_boot_dir')
        parser.add_argument(
            '-r', '--rm-bootstrap-dir',
            help='remove target directory after finishind',
            dest='rm_bootstrap_dir', action='store_true', default=False)
        parser.add_argument('-s', '--suite', help='suite used',
                            dest='suite', default="stable")
        parser.add_argument(
            '-t', '--trigger-command',
            help='trigger-command that will be added to cdist config',
            dest='trigger_command')
        parser.add_argument(
            '-y', '--remote-copy',
            help='remote copy that cdist config will use',
            dest='remote_copy', default=default_remote_copy)
        parser.epilog = cdist.argparse.EPILOG

        cdist.argparse.add_beta_command(cls.preos_name)
        args = parser.parse_args(argv)
        args.command = cls.preos_name
        cdist.argparse.check_beta(vars(args))

        cdist.preos.check_root()

        args.target_dir = os.path.realpath(args.target_dir[0])
        args.os = cls.preos_name
        args.remote_exec = os.path.realpath(args.remote_exec)
        args.remote_copy = os.path.realpath(args.remote_copy)
        args.manifest = os.path.realpath(args.manifest)
        if args.keyfile:
            new_keyfile = [os.path.realpath(x) for x in args.keyfile]
            args.keyfile = new_keyfile
        if args.pxe_boot_dir:
            args.pxe_boot_dir = os.path.realpath(args.pxe_boot_dir)

        cdist.argparse.handle_loglevel(args)
        log.debug("preos: {}, args: {}".format(cls.preos_name, args))
        try:
            env = vars(args)
            new_env = {}
            for key in env:
                if not env[key]:
                    new_env[key] = ''
                elif isinstance(env[key], bool) and env[key]:
                    new_env[key] = "yes"
                elif isinstance(env[key], list):
                    val = env[key]
                    new_env[key + "_cnt"] = str(len(val))
                    for i, v in enumerate(val):
                        new_env[key + "_" + str(i)] = v
                else:
                    new_env[key] = env[key]
            env = new_env
            env.update(os.environ)
            log.debug("preos: {} env: {}".format(cls.preos_name, env))
            subprocess.check_call(cmd, env=env, shell=True)
        except subprocess.CalledProcessError as e:
            log.error("preos {} failed: {}".format(cls.preos_name, e))
