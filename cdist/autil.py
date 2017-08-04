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


import cdist
import tarfile
import os
import glob
import tempfile


_ARCHIVING_MODES = {
    'tar': '',
    'tgz': 'gz',
    'tbz2': 'bz2',
    'txz': 'xz',
}


_UNARCHIVE_OPT = {
    'tar': None,
    'tgz': '-z',
    'tbz2': '-j',
    'txz': '-J',
}


# Archiving will be enabled if directory contains more than FILES_LIMIT files.
FILES_LIMIT = 1


def get_extract_option(mode):
    return _UNARCHIVE_OPT[mode]


def tar(source, mode="tgz"):
    if mode not in _ARCHIVING_MODES:
        raise cdist.Error("Unsupported archiving mode {}.".format(mode))

    files = glob.glob1(source, '*')
    fcnt = len(files)
    if fcnt <= FILES_LIMIT:
        return None, fcnt

    tarmode = 'w:{}'.format(_ARCHIVING_MODES[mode])
    _, tarpath = tempfile.mkstemp(suffix='.' + mode)
    with tarfile.open(tarpath, tarmode, dereference=True) as tar:
        if os.path.isdir(source):
            for f in files:
                tar.add(os.path.join(source, f), arcname=f)
        else:
            tar.add(source)
    return tarpath, fcnt
