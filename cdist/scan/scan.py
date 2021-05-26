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

from multiprocessing import Process
import os
import logging
from scapy.all import *

# Datetime overwrites scapy.all.datetime - needs to be imported AFTER
import datetime

import cdist.config

logging.basicConfig(level=logging.DEBUG)
log = logging.getLogger("scan")
datetime_format = '%Y-%m-%d %H:%M:%S'


class Host(object):
    def __init__(self, addr, outdir, name_mapper=None):
        self.addr = addr
        self.workdir = os.path.join(outdir, addr)
        self.name_mapper = name_mapper

        os.makedirs(self.workdir, exist_ok=True)

    def __get(self, key, default=None):
        fname = os.path.join(self.workdir, key)
        value = default
        if os.path.isfile(fname):
            with open(fname, "r") as fd:
                value = fd.readline()
        return value

    def __set(self, key, value):
        fname = os.path.join(self.workdir, key)
        with open(fname, "w") as fd:
            fd.write(f"{value}")

    def name(self, default=None):
        if self.name_mapper is None:
            return default

        fpath = os.path.join(os.getcwd(), self.name_mapper)
        if os.path.isfile(fpath) and os.access(fpath, os.X_OK):
            out = subprocess.run([fpath, self.addr], capture_output=True)
            if out.returncode != 0:
                return default
            else:
                value = out.stdout.decode()
                return (default if len(value) == 0 else value)
        else:
            return default

    def address(self):
        return self.addr

    def last_seen(self, default=None):
        raw = self.__get('last_seen')
        if raw:
            return datetime.datetime.strptime(raw, datetime_format)
        else:
            return default

    def last_configured(self, default=None):
        raw = self.__get('last_configured')
        if raw:
            return datetime.datetime.strptime(raw, datetime_format)
        else:
            return default

    def seen(self):
        now = datetime.datetime.now().strftime(datetime_format)
        self.__set('last_seen', now)

    # XXX: There's no easy way to use the config module without feeding it with
    # CLI args. Might as well call everything from scratch!
    def configure(self):
        target = self.name() or self.address()
        cmd = ['cdist', 'config', '-v', target]

        fname = os.path.join(self.workdir, 'last_configuration_log')
        with open(fname, "w") as fd:
            log.debug("Executing: %s", cmd)
            completed_process = subprocess.run(cmd, stdout=fd, stderr=fd)
            if completed_process.returncode != 0:
                log.error("%s return with non-zero code %i - see %s for \
                        details.", cmd, completed_process.returncode, fname)

        now = datetime.datetime.now().strftime(datetime_format)
        self.__set('last_configured', now)


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
            packet = IPv6(
                    dst="ff02::1%{}".format(interface)
                    ) / ICMPv6EchoRequest()
            send(packet, verbose=self.verbose)
        except Exception as e:
            log.error("Could not send ICMPv6EchoRequest: %s", e)


class Scanner(object):
    """
    Scan for replies of hosts, maintain the up-to-date database
    """

    def __init__(self, interfaces, autoconfigure=False, outdir=None,
                 name_mapper=None):
        self.interfaces = interfaces
        self.autoconfigure = autoconfigure
        self.name_mapper = name_mapper
        self.config_delay = datetime.timedelta(seconds=3600)

        if outdir:
            self.outdir = outdir
        else:
            self.outdir = os.path.join(os.environ['HOME'], '.cdist', 'scan')
        os.makedirs(self.outdir, exist_ok=True)

        self.running_configs = {}

    def handle_pkg(self, pkg):
        if ICMPv6EchoReply in pkg:
            host = Host(pkg['IPv6'].src, self.outdir, self.name_mapper)
            if host.name():
                log.verbose("Host %s (%s) is alive", host.name(),
                            host.address())
            else:
                log.verbose("Host %s is alive", host.address())

            host.seen()

            # Configure if needed.
            if self.autoconfigure and \
                    host.last_configured(default=datetime.datetime.min) + \
                    self.config_delay < datetime.datetime.now():
                self.config(host)

    def list(self):
        hosts = []
        for addr in os.listdir(self.outdir):
            hosts.append(Host(addr, self.outdir, self.name_mapper))

        return hosts

    def config(self, host):
        if host.name() is None:
            log.debug("config - could not resolve name for %s, aborting.",
                      host.address())
            return

        previous_config_process = self.running_configs.get(host.name())
        if previous_config_process is not None and \
                previous_config_process.is_alive():
            log.debug("config - is already running for %s, aborting.",
                      host.name())

        log.info("config - running against host %s (%s).", host.name(),
                 host.address())
        p = Process(target=host.configure())
        p.start()
        self.running_configs[host.name()] = p

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
            log.error("Could not start listener: %s", e)
