# -*- coding: utf-8 -*-
#
# 2013 Nico Schottelius (nico-cdist at schottelius.org)
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
import subprocess
import stat
import tempfile


import cdist.config
import cdist.exec.local
import cdist.exec.remote

log = logging.getLogger(__name__)

class PreOSExistsError(cdist.Error):
    def __init__(self, path):
        self.path = path

    def __str__(self):
        return 'Path %s already exists' % self.path


class PreOS(object):

    def __init__(self, target_dir, arch="amd64"):

        self.target_dir = target_dir
        self.arch = arch

        self.command = "debootstrap"
        self.suite  = "wheezy"
        self.options = [ "--include=openssh-server",
            "--arch=%s" % self.arch ]

        self._init_helper()

    def _init_helper(self):
        self.helper = {}
        self.helper["manifest"]  = """
for pkg in linux-image-amd64 openssh-server; do
    __package $pkg --state present
done
"""
        self.helper["remote_exec"]  = """#!/bin/sh
#        echo $@
#        set -x
chroot="$1"; shift

script=$(mktemp "${chroot}/tmp/chroot-${0##*/}.XXXXXXXXXX")
trap cleanup INT TERM EXIT
cleanup() {
   [ $__cdist_debug ] || rm "$script"
}

echo "#!/bin/sh -l" > "$script"
echo "$@" >> "$script"
chmod +x "$script"

relative_script="${script#$chroot}"

# run in chroot
chroot "$chroot" "$relative_script"
"""

        self.helper["remote_copy"]  = """#!/bin/sh
        echo $@
        set -x
src=$1; shift
dst=$1; shift
real_dst=$(echo $dst | sed 's,:,,')
cp -L "$src" "$real_dst"
"""

    @property
    def exists(self):
        return os.path.exists(self.target_dir)

    def bootstrap(self):
        if self.exists:
            raise PreOSExistsError(self.target_dir)

        cmd = [ self.command ]
        cmd.extend(self.options)
        cmd.append(self.suite)
        cmd.append(self.target_dir)

        log.debug("Bootstrap: %s" % cmd)

        subprocess.call(cmd)

    def create_helper_files(self, base_dir):
        for key, val in self.helper.items():
            filename = os.path.join(base_dir, key)
            with open(filename, "w") as fd:
                fd.write(val)
            os.chmod(filename, stat.S_IRUSR |  stat.S_IXUSR)

    def config(self):
        handle, path = tempfile.mkstemp(prefix='cdist.stdin.')
        with tempfile.TemporaryDirectory() as tempdir:
            host = self.target_dir

            self.create_helper_files(tempdir)

            local = cdist.exec.local.Local(
                target_host=host,
                initial_manifest=os.path.join(tempdir, "manifest")
            )

            remote = cdist.exec.remote.Remote(
                target_host=host,
                remote_exec=os.path.join(tempdir, "remote_exec"),
                remote_copy=os.path.join(tempdir, "remote_copy"),
            )

            config = cdist.config.Config(local, remote)
            config.run()

    @classmethod
    def commandline(cls, args):
        self = cls(target_dir=args.target_dir[0],
            arch=args.arch)

        if args.bootstrap:
            self.bootstrap()
        if args.config:
            self.config()
