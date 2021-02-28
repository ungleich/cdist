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

log = logging.getLogger("scan")


class Trigger(object):
    """
    Trigger an ICMPv6EchoReply from all hosts that are alive
    """

    def __init__(self, interfaces=None, verbose=False):
        self.interfaces = interfaces
        self.verbose = verbose

        # Wait 5 seconds before triggering again - FIXME: add parameter
        self.sleeptime = 5

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
        packet = IPv6(dst=f"ff02::1%{interface}") / ICMPv6EchoRequest()
        log.debug(f"Sending request on {interface}")
        send(packet, verbose=self.verbose)


class Scanner(object):
    """
    Scan for replies of hosts, maintain the up-to-date database
    """

    def __init__(self, interfaces=None, args=None, outdir=None):
        self.interfaces = interfaces

        if outdir:
            self.outdir = outdir
        else:
            self.outdir = os.path.join(os.environ['HOME'], '.cdist', 'scan')

    def handle_pkg(self, pkg):
        if ICMPv6EchoReply in pkg:
            host = pkg['IPv6'].src
            log.verbose(f"Host {host} is alive")

            dir = os.path.join(self.outdir, host)
            fname = os.path.join(dir, "last_seen")

            now = datetime.datetime.now()

            os.makedirs(dir, exist_ok=True)

            # FIXME: maybe adjust the format so we can easily parse again
            with open(fname, "w") as fd:
                fd.write(f"{now}\n")

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
        sniff(iface=self.interfaces,
              filter="icmp6",
              prn=self.handle_pkg)


if __name__ == '__main__':
    t = Trigger(interfaces=["wlan0"])
    t.start()

    # Scanner can listen on many interfaces at the same time
    s = Scanner(interfaces=["wlan0"])
    s.scan()

    # Join back the trigger processes
    t.join()

    # Test in my lan shows:
    # [18:48] bridge:cdist% ls -1d fe80::*
    # fe80::142d:f0a5:725b:1103
    # fe80::20d:b9ff:fe49:ac11
    # fe80::20d:b9ff:fe4c:547d
    # fe80::219:d2ff:feb2:2e12
    # fe80::21b:fcff:feee:f446
    # fe80::21b:fcff:feee:f45c
    # fe80::21b:fcff:feee:f4b1
    # fe80::21b:fcff:feee:f4ba
    # fe80::21b:fcff:feee:f4bc
    # fe80::21b:fcff:feee:f4c1
    # fe80::21d:72ff:fe86:46b
    # fe80::42b0:34ff:fe6f:f6f0
    # fe80::42b0:34ff:fe6f:f863
    # fe80::42b0:34ff:fe6f:f9b2
    # fe80::4a5d:60ff:fea1:e55f
    # fe80::77a3:5e3f:82cc:f2e5
    # fe80::9e93:4eff:fe6c:c1f4
    # fe80::ba69:f4ff:fec5:6041
    # fe80::ba69:f4ff:fec5:8db7
    # fe80::bad8:12ff:fe65:313d
    # fe80::bad8:12ff:fe65:d9b1
    # fe80::ce2d:e0ff:fed4:2611
    # fe80::ce32:e5ff:fe79:7ea7
    # fe80::d66d:6dff:fe33:e00
    # fe80::e2ff:f7ff:fe00:20e6
    # fe80::f29f:c2ff:fe7c:275e
