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

from scapy.all import *
from scapy.data import ETHER_TYPES


class Scanner(object):
    def recv_msg_cpu(self, pkg):
#        print(pkg.__repr__())
        if ICMPv6EchoReply in pkg:
            host = pkg['IPv6'].src
            print(f"Host {host} is alive")


    def scan(self):
        sniff(iface="wlan0",
              filter="icmp6",
              prn=self.recv_msg_cpu)


if __name__ == '__main__':
    s = Scanner()
    s.scan()
