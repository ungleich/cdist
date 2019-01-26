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

import ipaddress
import logging
import re
import socket
import http.server
import os
import socketserver
import shutil

import cdist.config
import cdist.log
import cdist.util.ipaddr as ipaddr


class Trigger():
    """cdist trigger handling"""

    # Arguments that are only trigger specific
    triggers_args = ["http_port", "ipv6", "directory", "source", ]

    def __init__(self, http_port=None, dry_run=False, ipv6=False,
                 directory=None, source=None, cdistargs=None):
        self.dry_run = dry_run
        self.http_port = int(http_port)
        self.ipv6 = ipv6
        self.args = cdistargs

        self.directory = directory
        self.source = source

        log.debug("IPv6: %s", self.ipv6)

    def run_httpd(self):
        server_address = ('', self.http_port)

        if self.ipv6:
            httpdcls = HTTPServerV6
        else:
            httpdcls = HTTPServerV4
        httpd = httpdcls(self.args, self.directory, self.source,
                         server_address, TriggerHttp)

        log.debug("Starting server at port %d", self.http_port)
        if self.dry_run:
            log.debug("Running in dry run mode")
        httpd.serve_forever()

    def run(self):
        if self.http_port:
            self.run_httpd()

    @classmethod
    def commandline(cls, args):
        global log

        # remove root logger default cdist handler and configure trigger's own
        logging.getLogger().handlers = []
        logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s')

        log = logging.getLogger("trigger")
        ownargs = {}
        for targ in cls.triggers_args:
            arg = getattr(args, targ)
            ownargs[targ] = arg

            del arg

        t = cls(dry_run=args.dry_run, cdistargs=args, **ownargs)
        t.run()


class TriggerHttp(http.server.BaseHTTPRequestHandler):
    actions = {
        "cdist": ["config", "install", ],
        "file":  ["present", "absent", ],
    }

    def do_HEAD(self):
        self.dispatch_request()

    def do_POST(self):
        self.dispatch_request()

    def do_GET(self):
        self.dispatch_request()

    def _actions_regex(self):
        regex = ["^/(?P<subsystem>", ]
        regex.extend("|".join(self.actions.keys()))
        regex.append(")/(?P<action>")
        regex.extend("|".join("|".join(self.actions[x]) for x in self.actions))
        regex.append(")/")

        return "".join(regex)

    def dispatch_request(self):
        host = self.client_address[0]
        code = 200
        message = None

        self.cdistargs = self.server.cdistargs

        actions_regex = self._actions_regex()
        m = re.match(actions_regex, self.path)

        if m:
            subsystem = m.group('subsystem')
            action = m.group('action')
            handler = getattr(self, "handler_" + subsystem)

            if action not in self.actions[subsystem]:
                code = 404
        else:
            code = 404

        if code == 200:
            log.debug("Calling {} -> {}".format(subsystem, action))
            try:
                handler(action, host)
            except cdist.Error as e:
                # cdist is not broken, cdist run is broken
                code = 599  # use arbitrary unassigned error code
                message = str(e)
            except Exception as e:
                # cdist/trigger server is broken
                code = 500

        self.send_response(code=code, message=message)
        self.end_headers()

    def handler_file(self, action, host):
        if not self.server.directory or not self.server.source:
            log.info("Cannot serve file request: directory or source "
                     "not setup")
            return

        try:
            ipaddress.ip_address(host)
        except ValueError:
            log.error("Host is not a valid IP address - aborting")
            return

        dst = os.path.join(self.server.directory, host)

        if action == "present":
            shutil.copyfile(self.server.source, dst)
        if action == "absent":
            if os.path.exists(dst):
                os.remove(dst)

    def handler_cdist(self, action, host):
        log.debug("Running cdist action %s for %s", action, host)

        if self.server.dry_run:
            log.info("Dry run, skipping cdist execution")
            return

        cname = action.title()
        module = getattr(cdist, action)
        theclass = getattr(module, cname)

        if hasattr(self.cdistargs, 'out_path'):
            out_path = self.cdistargs.out_path
        else:
            out_path = None
        host_base_path, hostdir = theclass.create_host_base_dirs(
            host, theclass.create_base_root_path(out_path))
        theclass.construct_remote_exec_copy_patterns(self.cdistargs)
        host_tags = None
        host_name = ipaddr.resolve_target_host_name(host)
        log.debug('Resolved target host name: %s', host_name)
        if host_name:
            target_host = host_name
        else:
            target_host = host
        log.debug('Using target_host: %s', target_host)
        log.debug("Executing cdist onehost with params: %s, %s, %s, %s, %s, ",
                  target_host, host_tags, host_base_path, hostdir,
                  self.cdistargs)
        theclass.onehost(target_host, host_tags, host_base_path, hostdir,
                         self.cdistargs, parallel=False)


class HTTPServerV6(socketserver.ForkingMixIn, http.server.HTTPServer):
    """
    Server that listens to both IPv4 and IPv6 requests.
    """
    address_family = socket.AF_INET6

    def __init__(self, cdistargs, directory, source, *args, **kwargs):
        self.cdistargs = cdistargs
        self.dry_run = cdistargs.dry_run
        self.directory = directory
        self.source = source

        http.server.HTTPServer.__init__(self, *args, **kwargs)


class HTTPServerV4(HTTPServerV6):
    """
    Server that listens to IPv4 requests.
    """
    address_family = socket.AF_INET
