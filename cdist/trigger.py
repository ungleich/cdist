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
import socketserver

import multiprocessing

import cdist.config
import cdist.install

log = logging.getLogger(__name__)

class Trigger():
    """cdist trigger handling"""

    def __init__(self, http_port=None, dry_run=False, ipv6=False,
                 cdistargs=None):
        self.log = logging.getLogger("trigger")
        self.dry_run = dry_run
        self.http_port = int(http_port)
        self.ipv6 = ipv6
        self.args = cdistargs
        log.debug("IPv6: %s", self.ipv6)

    def run_httpd(self):
        server_address = ('', self.http_port)

        if self.ipv6:
            httpdcls = HTTPServerV6
        else:
            httpdcls = HTTPServerV4
        httpd = httpdcls(self.args, server_address, TriggerHttp)

        log.debug("Starting server at port %d", self.http_port)
        if self.dry_run:
            log.debug("Running in dry run mode")
        httpd.serve_forever()

    def run(self):
        if self.http_port:
            self.run_httpd()

    @staticmethod
    def commandline(args):
        http_port = args.http_port
        ipv6 = args.ipv6
        del args.http_port
        del args.ipv6
        t = Trigger(http_port=http_port, dry_run=args.dry_run, ipv6=ipv6,
                    cdistargs=args)
        t.run()

class TriggerHttp(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        host = self.client_address[0]
        code = 200
        mode = None

        self.cdistargs = self.server.cdistargs

        m = re.match("^/(?P<mode>config|install)/.*", self.path)
        if m:
            mode = m.group('mode')
        else:
            code = 404
        if mode:
            log.debug("Running cdist for %s in mode %s", host, mode)
            if self.server.dry_run:
                log.info("Dry run, skipping cdist execution")
            else:
                self.run_cdist(mode, host)
        else:
            log.info("Unsupported mode in path %s, ignoring", self.path)

        self.send_response(code)
        self.end_headers()

    def do_HEAD(self):
        self.do_GET()

    def do_POST(self):
        self.do_GET()

    def run_cdist(self, mode, host):
        log.debug("Running cdist for %s in mode %s", host, mode)

        cname = mode.title()
        module = getattr(cdist, mode)
        theclass = getattr(module, cname)

        if hasattr(self.cdistargs, 'out_path'):
            out_path = self.cdistargs.out_path
        else:
            out_path = None
        host_base_path, hostdir = theclass.create_host_base_dirs(
            host, theclass.create_base_root_path(out_path))
        theclass.construct_remote_exec_copy_patterns(self.cdistargs)
        log.debug("Executing cdist onehost with params: %s, %s, %s, %s, ",
                  host, host_base_path, hostdir, self.cdistargs)
        theclass.onehost(host, host_base_path, hostdir, self.cdistargs,
                         parallel=False)


class HTTPServerV6(socketserver.ForkingMixIn, http.server.HTTPServer):
    """
    Server that listens to both IPv4 and IPv6 requests.
    """
    address_family = socket.AF_INET6

    def __init__(self, cdistargs, *args, **kwargs):
        self.cdistargs = cdistargs
        self.dry_run = cdistargs.dry_run
        http.server.HTTPServer.__init__(self, *args, **kwargs)

class HTTPServerV4(HTTPServerV6):
    """
    Server that listens to IPv4 requests.
    """
    address_family = socket.AF_INET
