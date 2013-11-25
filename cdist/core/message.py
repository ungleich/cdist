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
import shutil
import tempfile

import cdist

log = logging.getLogger(__name__)


class Message(object):
    """Support messaging between types

    """
    def __init__(self, prefix, global_messages):
        self.prefix = prefix
        self.global_messages = global_messages

        self.messages_in  = tempfile.mkstemp(suffix='.cdist_message_in')
        self.messages_out = tempfile.mkstemp(suffix='.cdist_message_out')

        shutil.copyfile(self.global_messages, self.messages_in)

    @property
    def env(self, env):
        env = {}
        env['__messages_in']  = self.messages_in
        env['__messages_out'] = self.messages_out

        return env

    def _cleanup(self):
        os.remove(self.messages_in)
        os.remove(self.messages_out)

    def _merge_messages(self):
        with open(self.messages_in) as fd:
            content = fd.readlines()

        with open(self.global_messages, 'a') as fd:
            for line in content:
                fd.write("%s:%s" % (self.prefix, line))

    def merge_messages(self):
        self._merge_messages()
        self._cleanup()
