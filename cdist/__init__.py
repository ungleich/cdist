# -*- coding: utf-8 -*-
#
# 2010-2015 Nico Schottelius (nico-cdist at schottelius.org)
# 2012-2017 Steven Armstrong (steven-cdist at armstrong.cc)
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

import os
import hashlib

import cdist.log
import cdist.version

VERSION = cdist.version.VERSION

BANNER = """
             ..          .       .x+=:.        s
           dF           @88>    z`    ^%      :8
          '88bu.        %8P        .   <k    .88
      .   '*88888bu      .       .@8Ned8"   :888ooo
 .udR88N    ^"*8888N   .@88u   .@^%8888"  -*8888888
<888'888k  beWE "888L ''888E` x88:  `)8b.   8888
9888 'Y"   888E  888E   888E  8888N=*8888   8888
9888       888E  888E   888E   %8"    R88   8888
9888       888E  888F   888E    @8Wou 9%   .8888Lu=
?8888u../ .888N..888    888&  .888888P`    ^%888*
 "8888P'   `"888*""     R888" `   ^"F        'Y"
   "P'        ""         ""
"""

REMOTE_COPY = "scp -o User=root -q"
REMOTE_EXEC = "ssh -o User=root"
REMOTE_CMDS_CLEANUP_PATTERN = "ssh -o User=root -O exit -S {}"


class Error(Exception):
    """Base exception class for this project"""
    pass


class UnresolvableRequirementsError(cdist.Error):
    """Resolving requirements failed"""
    pass


class CdistBetaRequired(cdist.Error):
    """Beta functionality is used but beta is not enabled"""

    def __init__(self, command, arg=None):
        self.command = command
        self.arg = arg

    def __str__(self):
        if self.arg is None:
            err_msg = ("\'{}\' command is beta, but beta is "
                       "not enabled. If you want to use it please enable beta "
                       "functionalities by using the -b/--beta command "
                       "line flag or setting CDIST_BETA env var.")
            fmt_args = [self.command, ]
        else:
            err_msg = ("\'{}\' argument of \'{}\' command is beta, but beta "
                       "is not enabled. If you want to use it please enable "
                       "beta functionalities by using the -b/--beta "
                       "command line flag or setting CDIST_BETA env var.")
            fmt_args = [self.arg, self.command, ]
        return err_msg.format(*fmt_args)


class CdistEntityError(Error):
    """Something went wrong while executing cdist entity"""
    def __init__(self, entity_name, entity_params, stdout_paths,
                 stderr_paths, subject=''):
        self.entity_name = entity_name
        self.entity_params = entity_params
        self.stderr_paths = stderr_paths
        self.stdout_paths = stdout_paths
        if isinstance(subject, Error):
            self.original_error = subject
        else:
            self.original_error = None
        self.message = str(subject)

    def _stdpath(self, stdpaths, header_name):
        result = {}
        for name, path in stdpaths:
            if name not in result:
                result[name] = []
            try:
                if os.path.exists(path) and os.path.getsize(path) > 0:
                    output = []
                    label_begin = name + ":" + header_name
                    output.append(label_begin)
                    output.append('\n')
                    output.append('-' * len(label_begin))
                    output.append('\n')
                    with open(path, 'r') as fd:
                        output.append(fd.read())
                    output.append('\n')
                    result[name].append(''.join(output))
            except UnicodeError as ue:
                result[name].append(('Cannot output {}:{} due to: {}.\n'
                                     'You can try to read the error file "{}"'
                                     ' yourself.').format(
                                         name, header_name, ue, path))
        return result

    def _stderr(self):
        return self._stdpath(self.stderr_paths, 'stderr')

    def _stdout(self):
        return self._stdpath(self.stdout_paths, 'stdout')

    def _update_dict_list(self, target, source):
        for x in source:
            if x not in target:
                target[x] = []
            target[x].extend(source[x])

    @property
    def std_streams(self):
        std_dict = {}
        self._update_dict_list(std_dict, self._stdout())
        self._update_dict_list(std_dict, self._stderr())
        return std_dict

    def __str__(self):
        output = []
        output.append(self.message)
        output.append('\n\n')
        header = "Error processing " + self.entity_name
        under_header = '=' * len(header)
        output.append(header)
        output.append('\n')
        output.append(under_header)
        output.append('\n')
        for param_name, param_value in self.entity_params:
            output.append(param_name + ': ' + str(param_value))
            output.append('\n')
        output.append('\n')
        for x in self.std_streams:
            output.append(''.join(self.std_streams[x]))
        return ''.join(output)


class CdistObjectError(CdistEntityError):
    """Something went wrong while working on a specific cdist object"""
    def __init__(self, cdist_object, subject=''):
        params = [
            ('name', cdist_object.name, ),
            ('path', cdist_object.absolute_path, ),
            ('source', " ".join(cdist_object.source), ),
            ('type', os.path.realpath(
                cdist_object.cdist_type.absolute_path), ),
        ]
        stderr_paths = []
        for stderr_name in os.listdir(cdist_object.stderr_path):
            stderr_path = os.path.join(cdist_object.stderr_path,
                                       stderr_name)
            stderr_paths.append((stderr_name, stderr_path, ))
        stdout_paths = []
        for stdout_name in os.listdir(cdist_object.stdout_path):
            stdout_path = os.path.join(cdist_object.stdout_path,
                                       stdout_name)
            stdout_paths.append((stdout_name, stdout_path, ))
        super().__init__("object '{}'".format(cdist_object.name),
                         params, stdout_paths, stderr_paths, subject)


class InitialManifestError(CdistEntityError):
    """Something went wrong while executing initial manifest"""
    def __init__(self, initial_manifest, stdout_path, stderr_path, subject=''):
        params = [
            ('path', initial_manifest, ),
        ]
        stdout_paths = []
        stdout_paths = [
            ('init', stdout_path, ),
        ]
        stderr_paths = []
        stderr_paths = [
            ('init', stderr_path, ),
        ]
        super().__init__('initial manifest', params, stdout_paths,
                         stderr_paths, subject)


def file_to_list(filename):
    """Return list from \n seperated file"""
    if os.path.isfile(filename):
        file_fd = open(filename, "r")
        lines = file_fd.readlines()
        file_fd.close()

        # Remove \n from all lines
        lines = map(lambda s: s.strip(), lines)
    else:
        lines = []

    return lines


def str_hash(s):
    """Return hash of string s"""
    if isinstance(s, str):
        return hashlib.md5(s.encode('utf-8')).hexdigest()
    else:
        raise Error("Param should be string")


def home_dir():
    if 'HOME' in os.environ:
        home = os.environ['HOME']
        if home:
            rv = os.path.join(home, ".cdist")
        else:
            rv = None
    else:
        rv = None
    return rv
