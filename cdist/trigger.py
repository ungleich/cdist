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
import re
import socket
import http.server

from http.server import BaseHTTPRequestHandler, HTTPServer

import multiprocessing

import cdist

log = logging.getLogger(__name__)

class Trigger():
    """cdist trigger handling"""

    def __init__(self, http_port=None, dry_run=False, ipv4only=False):
        self.log = logging.getLogger("trigger")
        self.dry_run = dry_run
        self.http_port = int(http_port)
        self.ipv4only = ipv4only

        # can only be set once
        multiprocessing.set_start_method('forkserver')

    def run_httpd(self):
        server_address = ('', self.http_port)

        if self.ipv4only:
            httpd = HTTPServerV4(server_address, TriggerHttp)
        else:
            httpd = HTTPServerV6(server_address, TriggerHttp)

        httpd.serve_forever()

    def run(self):
        if self.http_port:
            self.run_httpd()

    @staticmethod
    def commandline(args):
        t = Trigger(http_port=args.http_port, ipv4only=args.ipv4)
        t.run()

class TriggerHttp(BaseHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        http.server.BaseHTTPRequestHandler.__init__(self, *args, **kwargs)

    def do_GET(self):
        # FIXME: dispatch to pool instead of single process
        host = self.client_address[0]
        code = 200
        mode = None

        m = re.match("^/(?P<mode>config|install)/.*", self.path)
        if m:
            mode = m.group('mode')
        else:
            code = 404

        if mode:
            self.run_cdist(mode, host)

        self.send_response(code)
        self.end_headers()

    def do_HEAD(self):
        self.do_GET()

    def do_POST(self):
        self.do_GET()

    def run_cdist(self, mode, host):
        log.debug("Running cdist {} {}".format(mode, host))


class HTTPServerV4(http.server.HTTPServer):
    """
    Server that listens to IPv4 and IPv6 requests
    """
    address_family = socket.AF_INET


class HTTPServerV6(http.server.HTTPServer):
    """
    Server that listens both to IPv4 and IPv6 requests
    """
    address_family = socket.AF_INET6
