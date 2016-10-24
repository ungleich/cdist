#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2016 Nico Schottelius (nico-cdist at schottelius.org)
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
import sys
import time
import tempfile
from http.server import BaseHTTPRequestHandler, HTTPServer


import cdist
from cdist import core

class Trigger():
    """cdist trigger handling"""

    def __init__(self, dry_run=False):
        self.log = logging.getLogger("trigger")
        self.dry_run = dry_run

    def run_http(self):
        server_address = ('0.0.0.0', 8000)
        httpd = HTTPServer(server_address, testHTTPServer_RequestHandler)
        print('running server...')
        httpd.serve_forever()

    @staticmethod
    def commandline(args):
        print("all good")
        pass


class TriggerHttp(BaseHTTPRequestHandler):
    def do_GET(self):
        pass
