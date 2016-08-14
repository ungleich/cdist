# -*- coding: utf-8 -*-
#
# 2011 Steven Armstrong (steven-cdist at armstrong.cc)
# 2011-2013 Nico Schottelius (nico-cdist at schottelius.org)
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

import logging
import os

import cdist

'''
common:
    runs only locally, does not need remote

    env:
        PATH: prepend directory with type emulator symlinks == local.bin_path
        __target_host: the target host we are working on
        __target_hostname: the target hostname provided from __target_host
        __target_fqdn: the target's fully qualified domain name provided from
                       __target_host
        __global: full qualified path to the global
                  output dir == local.out_path
        __cdist_manifest: full qualified path of the manifest == script
        __cdist_type_base_path: full qualified path to the directory where
                                types are defined for use in type emulator
            == local.type_path
        __files: full qualified path to the files dir

initial manifest is:
    script: full qualified path to the initial manifest

    env:
        __manifest: path to .../conf/manifest/ == local.manifest_path

    creates: new objects through type emulator

type manifeste is:
    script: full qualified path to the type manifest

    env:
        __object: full qualified path to the object's dir
        __object_id: the objects id
        __object_fq: full qualified object id, iow: $type.name + / + object_id
        __type: full qualified path to the type's dir

    creates: new objects through type emulator
'''


class NoInitialManifestError(cdist.Error):
    """
    Display missing initial manifest:
        - Display path if user given
            - try to resolve link if it is a link
        - Omit path if default (is a linked path in temp directory without
            much help)
    """

    def __init__(self, manifest_path, user_supplied):
        msg_header = "Initial manifest missing"

        if user_supplied:
            if os.path.islink(manifest_path):
                self.message = "%s: %s -> %s" % (
                        msg_header, manifest_path,
                        os.path.realpath(manifest_path))
            else:
                self.message = "%s: %s" % (msg_header, manifest_path)
        else:
            self.message = "%s" % (msg_header)

    def __str__(self):
        return repr(self.message)


class Manifest(object):
    """Executes cdist manifests.

    """
    def __init__(self, target_host, local):
        self.target_host = target_host
        self.local = local

        self.log = logging.getLogger(self.target_host[0])

        self.env = {
            'PATH': "%s:%s" % (self.local.bin_path, os.environ['PATH']),
            # for use in type emulator
            '__cdist_type_base_path': self.local.type_path,
            '__global': self.local.base_path,
            '__target_host': self.target_host[0],
            '__target_hostname': self.target_host[1],
            '__target_fqdn': self.target_host[2],
            '__files': self.local.files_path,
        }

        if self.log.getEffectiveLevel() == logging.DEBUG:
            self.env.update({'__cdist_debug': "yes"})

    def env_initial_manifest(self, initial_manifest):
        env = os.environ.copy()
        env.update(self.env)
        env['__cdist_manifest'] = initial_manifest
        env['__manifest'] = self.local.manifest_path
        env['__explorer'] = self.local.global_explorer_out_path

        return env

    def run_initial_manifest(self, initial_manifest=None):
        if not initial_manifest:
            initial_manifest = self.local.initial_manifest
            user_supplied = False
        else:
            user_supplied = True

        self.log.info("Running initial manifest " + initial_manifest)

        if not os.path.isfile(initial_manifest):
            raise NoInitialManifestError(initial_manifest, user_supplied)

        message_prefix = "initialmanifest"
        self.local.run_script(initial_manifest,
                              env=self.env_initial_manifest(initial_manifest),
                              message_prefix=message_prefix)

    def env_type_manifest(self, cdist_object):
        type_manifest = os.path.join(self.local.type_path,
                                     cdist_object.cdist_type.manifest_path)
        env = os.environ.copy()
        env.update(self.env)
        env.update({
            '__cdist_manifest': type_manifest,
            '__manifest': self.local.manifest_path,
            '__object': cdist_object.absolute_path,
            '__object_id': cdist_object.object_id,
            '__object_name': cdist_object.name,
            '__type': cdist_object.cdist_type.absolute_path,
        })

        return env

    def run_type_manifest(self, cdist_object):
        type_manifest = os.path.join(self.local.type_path,
                                     cdist_object.cdist_type.manifest_path)
        message_prefix = cdist_object.name
        if os.path.isfile(type_manifest):
            self.local.run_script(type_manifest,
                                  env=self.env_type_manifest(cdist_object),
                                  message_prefix=message_prefix)
