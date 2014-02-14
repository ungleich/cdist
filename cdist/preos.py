# -*- coding: utf-8 -*-
#
# 2013-2014 Nico Schottelius (nico-cdist at schottelius.org)
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
import glob
import os
import subprocess
import stat
import sys
import shutil
import tempfile

import cdist.config
import cdist.exec.local
import cdist.exec.remote

log = logging.getLogger(__name__)

DEFAULT_MANIFEST = """
for pkg in \
    file \
    linux-image-amd64 \
    openssh-server curl \
    syslinux grub2 \
    gdisk util-linux lvm2 mdadm \
    btrfs-tools e2fsprogs jfsutils reiser4progs xfsprogs; do
    __package $pkg --state present
done

# initramfs requires /init
__link /init --source /sbin/init --type symbolic

__file /etc/network/interfaces --source - --mode 0644 << eof
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
allow-hotplug eth0
iface eth0 inet dhcp
eof

# Steven found this out - coyping it 1:1
# fix the bloody 'stdin: is not a tty' problem
__line /root/.profile --line 'mesg n' --state absent
"""

class PreOSExistsError(cdist.Error):
    def __init__(self, path):
        self.path = path

    def __str__(self):
        return 'Path %s already exists' % self.path

class PreOSBootstrapError(cdist.Error):
    pass


class PreOS(object):

    def __init__(self, target_dir, arch="amd64"):

        self.target_dir = target_dir
        self.arch = arch

        self.command = "debootstrap"
        self.suite  = "wheezy"
        self.options = [ "--include=openssh-server",
            "--arch=%s" % self.arch ]

        self.pxelinux = "/usr/lib/syslinux/pxelinux.0"
        self.pxelinux_cfg = """
DEFAULT preos
LABEL preos
KERNEL kernel
INITRD initramfs
"""

    def _init_helper(self):
        self.helper = {}
        self.helper["manifest"]  = self.initial_manifest
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

# ensure PATH is setup
export PATH=$PATH:/bin:/usr/bin:/sbin:/usr/sbin

# run in chroot
chroot "$chroot" "$relative_script"
"""

        self.helper["remote_copy"]  = """#!/bin/sh
#        echo $@
#        set -x
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

#        try:
        subprocess.check_call(cmd)
#        except subprocess.CalledProcessError:
#            raise 

        # Required to run this - otherwise apt-get install fails
        cmd = [ "chroot", self.target_dir, "/usr/bin/apt-get", "update" ]
        subprocess.check_call(cmd)

    def create_helper_files(self, base_dir):
        for key, val in self.helper.items():
            filename = os.path.join(base_dir, key)
            with open(filename, "w") as fd:
                fd.write(val)
            os.chmod(filename, stat.S_IRUSR |  stat.S_IXUSR)

    def create_kernel(self):
        dst = os.path.join(self.out_dir, "kernel")
        srcglob = glob.glob("%s/boot/vmlinuz-*" % self.target_dir)
        src = srcglob[0]

        log.info("Creating kernel  ...")
        shutil.copyfile(src, dst, follow_symlinks=True)

    def create_pxelinux(self):
        dst = os.path.join(self.out_dir, "pxelinux.0")
        src = "%s/usr/lib/syslinux/pxelinux.0" % self.target_dir

        log.info("Creating pxelinux.0  ...")
        shutil.copyfile(src, dst, follow_symlinks=True)

    def create_pxeconfig(self):
        configdir = os.path.join(self.out_dir, "pxelinux.cfg")
        configfile = os.path.join(configdir, "default")
        log.info("Creating pxe configuration ...")
        if not os.path.isdir(configdir):
            os.mkdir(configdir)

        with open(configfile, "w") as fd:
            fd.write(self.pxelinux_cfg)

    def create_initramfs(self):
        out_file = os.path.join(self.out_dir, "initramfs")
        cmd="cd {target_dir}; find . -print0 | cpio --null -o --format=newc | gzip -9 > {out_file}".format(target_dir = self.target_dir, out_file = out_file)

        log.info("Creating initramfs ...")
        subprocess.check_call(cmd, shell=True)

    def ensure_out_dir_exists(self):
        os.makedirs(self.out_dir, exist_ok=True)


    def create_iso(self, out_dir):
        self.out_dir = out_dir

        self.ensure_out_dir_exists()

        raise cdist.Error("Generating ISO is not yet supported")

    def create_pxe(self, out_dir):
        self.out_dir = out_dir

        self.ensure_out_dir_exists()
        self.create_kernel()
        self.create_initramfs()
        self.create_pxeconfig()
        self.create_pxelinux()


    def setup_initial_manifest(self, user_initial_manifest, replace_manifest):
        if user_initial_manifest:
            if user_initial_manifest == '-':
                user_initial_manifest_content = sys.stdin.read()
            else:
                with open(user_initial_manifest, "r") as fd:
                    user_initial_manifest_content = fd.read()
        else:
            user_initial_manifest_content = ""

        if replace_manifest:
            self.initial_manifest = user_initial_manifest_content
        else:
            self.initial_manifest = "{default}\n# User supplied manifest\n{user}".format(default=DEFAULT_MANIFEST, user=user_initial_manifest_content)

    def config(self):
        self._init_helper()

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

    def cleanup(self):
        # Remove cruft from chroot
        for action in 'autoclean clean autoremove'.split():
            cmd = [ 'chroot', self.target_dir, '/usr/bin/apt-get', action]
            subprocess.check_call(cmd)

    @classmethod
    def commandline(cls, args):
        self = cls(target_dir=args.target_dir[0],
            arch=args.arch)

        # read initial manifest first - it may come from stdin
        if args.config:
            self.setup_initial_manifest(args.initial_manifest, args.replace_manifest)

        # Bootstrap: creates base directory
        if args.bootstrap:
            self.bootstrap()

        # Configure the OS
        if args.config:
            self.config()

        # Cleanup chroot
        self.cleanup()

        # Output pxe files
        if args.pxe_boot_dir:
            self.create_pxe(args.pxe_boot_dir)

        #if args.iso_boot_dir:
        #    self.create_iso(args.iso_boot)
