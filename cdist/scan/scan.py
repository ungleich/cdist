# -*- coding: utf-8 -*-
#
# 2020 Nico Schottelius (nico-cdist at schottelius.org)
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

#
# Interface to be implemented:
# - cdist scan --mode {scan, trigger, install, config}, --mode can be repeated
#   scan: scan / listen for icmp6 replies
#   trigger: send trigger to multicast
#   config: configure newly detected hosts
#   install: install newly detected hosts
#
# Scanner logic
#  - save results to configdir:
#     basedir = ~/.cdist/scan/<ipv6-address>
#     last_seen = ~/.cdist/scan/<ipv6-address>/last_seen -- record unix time
#           or similar
#     last_configured = ~/.cdist/scan/<ipv6-address>/last_configured -- record
#           unix time or similar
#     last_installed = ~/.cdist/scan/<ipv6-address>/last_configured -- record
#           unix time or similar
#
#
#
#
# cdist scan --list
#       Show all known hosts including last seen flag
#
# Logic for reconfiguration:
#
#  - record when configured last time
#  - introduce a parameter --reconfigure-after that takes time argument
#  - reconfigure if a) host alive and b) reconfigure-after time passed
#


from multiprocessing import Process
import os
import logging
from scapy.all import *

# Datetime overwrites scapy.all.datetime - needs to be imported AFTER
import datetime

import cdist.config

logging.basicConfig(level=logging.DEBUG)
log = logging.getLogger("scan")

class Trigger(object):
    """
    Trigger an ICMPv6EchoReply from all hosts that are alive
    """

    def __init__(self, interfaces, sleeptime, verbose=False):
        self.interfaces = interfaces

        # Used by scapy / send in trigger/2.
        self.verbose = verbose

        # Delay in seconds between sent ICMPv6EchoRequests.
        self.sleeptime = sleeptime

    def start(self):
        self.processes = []
        for interface in self.interfaces:
            p = Process(target=self.run_interface, args=(interface,))
            self.processes.append(p)
            p.start()

    def join(self):
        for process in self.processes:
            process.join()

    def run_interface(self, interface):
        while True:
            self.trigger(interface)
            time.sleep(self.sleeptime)

    def trigger(self, interface):
        try:
            log.debug("Sending ICMPv6EchoRequest on %s", interface)
            packet = IPv6(dst="ff02::1%{}".format(interface)) / ICMPv6EchoRequest()
            send(packet, verbose=self.verbose)
        except Exception as e:
            log.error( "Could not send ICMPv6EchoRequest: %s", e)


class Scanner(object):
    """
    Scan for replies of hosts, maintain the up-to-date database
    """

    def __init__(self, interfaces, args=None, outdir=None):
        self.interfaces = interfaces

        if outdir:
            self.outdir = outdir
        else:
            self.outdir = os.path.join(os.environ['HOME'], '.cdist', 'scan')

    def handle_pkg(self, pkg):
        if ICMPv6EchoReply in pkg:
            host = pkg['IPv6'].src
            log.verbose("Host %s is alive", host)

            dir = os.path.join(self.outdir, host)
            fname = os.path.join(dir, "last_seen")

            now = datetime.datetime.now()

            os.makedirs(dir, exist_ok=True)

            # FIXME: maybe adjust the format so we can easily parse again
            with open(fname, "w") as fd:
                fd.write(f"{now}\n")

    def list(self):
        hosts = dict()
        for linklocal_addr in os.listdir(self.outdir):
            workdir = os.path.join(self.outdir, linklocal_addr)
            # We ignore any (unexpected) file in this directory.
            if os.path.isdir(workdir):
                last_seen='-'
                last_seen_file = os.path.join(workdir, 'last_seen')
                if os.path.isfile(last_seen_file):
                    with open(last_seen_file, "r") as fd:
                        last_seen = fd.readline()

                hosts[linklocal_addr] = {'last_seen': last_seen}

        return hosts


    def config(self):
        """
        Configure a host

        - Assume we are only called if necessary
        - However we need to ensure to not run in parallel
        - Maybe keep dict storing per host processes
        - Save the result
        - Save the output -> probably aligned to config mode

        """

    def start(self):
        self.process = Process(target=self.scan)
        self.process.start()

    def join(self):
        self.process.join()

    def scan(self):
        log.debug("Scanning - zzzzz")
        try:
            sniff(iface=self.interfaces,
                  filter="icmp6",
                  prn=self.handle_pkg)
        except Exception as e:
            log.error( "Could not start listener: %s", e)
