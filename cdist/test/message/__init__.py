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

import os
import tempfile

from cdist import test
import cdist.message

class MessageTestCase(test.CdistTestCase):

    def setUp(self):
        self.prefix="cdist-test"
        self.content = "A very short story"
        self.tempfile = tempfile.mkstemp()[1]
        self.message = cdist.message.Message(prefix=self.prefix,
            messages=self.tempfile)

    def tearDown(self):
        os.remove(self.tempfile)
        self.message._cleanup()

    def test_env(self):
        """
        Ensure environment is correct
        """

        env = self.message.env

        self.assertIn('__messages_in', env)
        self.assertIn('__messages_out', env)


    def test_copy_content(self):
        """
        Ensure content copying is working
        """

        with open(self.tempfile, "w") as fd:
            fd.write(self.content)

        self.message._copy_messages()

        with open(self.tempfile, "r") as fd:
            testcontent = fd.read()

        self.assertEqual(self.content, testcontent)

    def test_message_merge_prefix(self):
        """Ensure messages are merged and are prefixed"""

        expectedcontent = "%s:%s" % (self.prefix, self.content)

        out = self.message.env['__messages_out']

        with open(out, "w") as fd:
            fd.write(self.content)

        self.message._merge_messages()

        with open(self.tempfile, "r") as fd:
            testcontent = fd.read()

        self.assertEqual(expectedcontent, testcontent)
