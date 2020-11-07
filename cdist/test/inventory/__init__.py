# -*- coding: utf-8 -*-
#
# 2016 Darko Poljak (darko.poljak at gmail.com)
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
import shutil
import cdist
import os.path as op
import unittest
import sys
from cdist import test
from cdist import inventory
from io import StringIO

my_dir = op.abspath(op.dirname(__file__))
fixtures = op.join(my_dir, 'fixtures')
inventory_dir = op.join(fixtures, "inventory")


class InventoryTestCase(test.CdistTestCase):

    def _create_host_with_tags(self, host, tags):
        os.makedirs(inventory_dir, exist_ok=True)
        hostfile = op.join(inventory_dir, host)
        with open(hostfile, "w") as f:
            for x in tags:
                f.write("{}\n".format(x))

    def setUp(self):
        self.maxDiff = None
        self.db = {
            "loadbalancer1": ["loadbalancer", "all", "europe", ],
            "loadbalancer2": ["loadbalancer", "all", "europe", ],
            "loadbalancer3": ["loadbalancer", "all", "africa", ],
            "loadbalancer4": ["loadbalancer", "all", "africa", ],
            "web1": ["web", "all", "static", ],
            "web2": ["web", "all", "dynamic", ],
            "web3": ["web", "all", "dynamic", ],
            "shell1": ["shell", "all", "free", ],
            "shell2": ["shell", "all", "free", ],
            "shell3": ["shell", "all", "charge", ],
            "shell4": ["shell", "all", "charge", ],
            "monty": ["web", "python", "shell", ],
            "python": ["web", "python", "shell", ],
        }
        for x in self.db:
            self.db[x] = sorted(self.db[x])
        for host in self.db:
            self._create_host_with_tags(host, self.db[host])
        self.sys_stdout = sys.stdout
        out = StringIO()
        sys.stdout = out

    def _get_output(self):
        sys.stdout.flush()
        output = sys.stdout.getvalue().strip()
        return output

    def tearDown(self):
        sys.stdout = self.sys_stdout
        shutil.rmtree(inventory_dir)

    def test_inventory_create_db(self):
        dbdir = op.join(fixtures, "foo")
        inv = inventory.Inventory(db_basedir=dbdir)
        self.assertTrue(os.path.isdir(dbdir))
        self.assertEqual(inv.db_basedir, dbdir)
        shutil.rmtree(inv.db_basedir)

    # InventoryList
    def test_inventory_list_print(self):
        invList = inventory.InventoryList(db_basedir=inventory_dir)
        invList.run()
        output = self._get_output()
        self.assertTrue(' ' in output)

    def test_inventory_list_print_host_only(self):
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          list_only_host=True)
        invList.run()
        output = self._get_output()
        self.assertFalse(' ' in output)

    def test_inventory_list_all(self):
        invList = inventory.InventoryList(db_basedir=inventory_dir)
        entries = invList.entries()
        db = {host: sorted(tags) for host, tags in entries}
        self.assertEqual(db, self.db)

    def test_inventory_list_by_host_hosts(self):
        hosts = ("web1", "web2", "web3",)
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          hosts=hosts)
        entries = invList.entries()
        db = {host: sorted(tags) for host, tags in entries}
        expected_db = {host: sorted(self.db[host]) for host in hosts}
        self.assertEqual(db, expected_db)

    def test_inventory_list_by_host_hostfile(self):
        hosts = ("web1", "web2", "web3",)
        hostfile = op.join(fixtures, "hosts")
        with open(hostfile, "w") as f:
            for x in hosts:
                f.write("{}\n".format(x))
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          hostfile=hostfile)
        entries = invList.entries()
        db = {host: sorted(tags) for host, tags in entries}
        expected_db = {host: sorted(self.db[host]) for host in hosts}
        self.assertEqual(db, expected_db)
        os.remove(hostfile)

    def test_inventory_list_by_host_hosts_hostfile(self):
        hosts = ("shell1", "shell4",)
        hostsf = ("web1", "web2", "web3",)
        hostfile = op.join(fixtures, "hosts")
        with open(hostfile, "w") as f:
            for x in hostsf:
                f.write("{}\n".format(x))
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          hosts=hosts, hostfile=hostfile)
        entries = invList.entries()
        db = {host: sorted(tags) for host, tags in entries}
        import itertools
        expected_db = {host: sorted(self.db[host]) for host in
                       itertools.chain(hostsf, hosts)}
        self.assertEqual(db, expected_db)
        os.remove(hostfile)

    def _gen_expected_db_for_tags(self, tags):
        db = {}
        for host in self.db:
            for tag in tags:
                if tag in self.db[host]:
                    db[host] = self.db[host]
                    break
        return db

    def _gen_expected_db_for_has_all_tags(self, tags):
        db = {}
        for host in self.db:
            if set(tags).issubset(set(self.db[host])):
                db[host] = self.db[host]
        return db

    def test_inventory_list_by_tag_hosts(self):
        tags = ("web", "shell",)
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          istag=True, hosts=tags)
        entries = invList.entries()
        db = {host: sorted(tags) for host, tags in entries}
        expected_db = self._gen_expected_db_for_tags(tags)
        self.assertEqual(db, expected_db)

    def test_inventory_list_by_tag_hostfile(self):
        tags = ("web", "shell",)
        tagfile = op.join(fixtures, "tags")
        with open(tagfile, "w") as f:
            for x in tags:
                f.write("{}\n".format(x))
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          istag=True, hostfile=tagfile)
        entries = invList.entries()
        db = {host: sorted(tags) for host, tags in entries}
        expected_db = self._gen_expected_db_for_tags(tags)
        self.assertEqual(db, expected_db)
        os.remove(tagfile)

    def test_inventory_list_by_tag_hosts_hostfile(self):
        tags = ("web", "shell",)
        tagsf = ("dynamic", "europe",)
        tagfile = op.join(fixtures, "tags")
        with open(tagfile, "w") as f:
            for x in tagsf:
                f.write("{}\n".format(x))
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          istag=True, hosts=tags,
                                          hostfile=tagfile)
        entries = invList.entries()
        db = {host: sorted(tags) for host, tags in entries}
        import itertools
        expected_db = self._gen_expected_db_for_tags(tags + tagsf)
        self.assertEqual(db, expected_db)
        os.remove(tagfile)

    def test_inventory_list_by_tag_has_all_tags(self):
        tags = ("web", "python", "shell",)
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          istag=True, hosts=tags,
                                          has_all_tags=True)
        entries = invList.entries()
        db = {host: sorted(tags) for host, tags in entries}
        expected_db = self._gen_expected_db_for_has_all_tags(tags)
        self.assertEqual(db, expected_db)

    # InventoryHost
    def test_inventory_host_add_hosts(self):
        hosts = ("spam", "eggs", "foo",)
        invHost = inventory.InventoryHost(db_basedir=inventory_dir,
                                          action="add", hosts=hosts)
        invHost.run()
        invList = inventory.InventoryList(db_basedir=inventory_dir)
        expected_hosts = tuple(x for x in invList.host_entries() if x in hosts)
        self.assertEqual(sorted(hosts), sorted(expected_hosts))

    def test_inventory_host_add_hostfile(self):
        hosts = ("spam-new", "eggs-new", "foo-new",)
        hostfile = op.join(fixtures, "hosts")
        with open(hostfile, "w") as f:
            for x in hosts:
                f.write("{}\n".format(x))
        invHost = inventory.InventoryHost(db_basedir=inventory_dir,
                                          action="add", hostfile=hostfile)
        invHost.run()
        invList = inventory.InventoryList(db_basedir=inventory_dir)
        expected_hosts = tuple(x for x in invList.host_entries() if x in hosts)
        self.assertEqual(sorted(hosts), sorted(expected_hosts))
        os.remove(hostfile)

    def test_inventory_host_add_hosts_hostfile(self):
        hosts = ("spam-spam", "eggs-spam", "foo-spam",)
        hostf = ("spam-eggs-spam", "spam-foo-spam",)
        hostfile = op.join(fixtures, "hosts")
        with open(hostfile, "w") as f:
            for x in hostf:
                f.write("{}\n".format(x))
        invHost = inventory.InventoryHost(db_basedir=inventory_dir,
                                          action="add", hosts=hosts,
                                          hostfile=hostfile)
        invHost.run()
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          hosts=hosts + hostf)
        expected_hosts = tuple(invList.host_entries())
        self.assertEqual(sorted(hosts + hostf), sorted(expected_hosts))
        os.remove(hostfile)

    def test_inventory_host_del_hosts(self):
        hosts = ("web1", "shell1",)
        invHost = inventory.InventoryHost(db_basedir=inventory_dir,
                                          action="del", hosts=hosts)
        invHost.run()
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          hosts=hosts)
        expected_hosts = tuple(invList.host_entries())
        self.assertTupleEqual(expected_hosts, ())

    def test_inventory_host_del_hostfile(self):
        hosts = ("loadbalancer3", "loadbalancer4",)
        hostfile = op.join(fixtures, "hosts")
        with open(hostfile, "w") as f:
            for x in hosts:
                f.write("{}\n".format(x))
        invHost = inventory.InventoryHost(db_basedir=inventory_dir,
                                          action="del", hostfile=hostfile)
        invHost.run()
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          hosts=hosts)
        expected_hosts = tuple(invList.host_entries())
        self.assertTupleEqual(expected_hosts, ())
        os.remove(hostfile)

    def test_inventory_host_del_hosts_hostfile(self):
        hosts = ("loadbalancer1", "loadbalancer2",)
        hostf = ("web2", "shell2",)
        hostfile = op.join(fixtures, "hosts")
        with open(hostfile, "w") as f:
            for x in hostf:
                f.write("{}\n".format(x))
        invHost = inventory.InventoryHost(db_basedir=inventory_dir,
                                          action="del", hosts=hosts,
                                          hostfile=hostfile)
        invHost.run()
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          hosts=hosts + hostf)
        expected_hosts = tuple(invList.host_entries())
        self.assertTupleEqual(expected_hosts, ())
        os.remove(hostfile)

    @unittest.expectedFailure
    def test_inventory_host_invalid_host(self):
        try:
            invalid_hostfile = op.join(inventory_dir, "invalid")
            os.mkdir(invalid_hostfile)
            hosts = ("invalid",)
            invHost = inventory.InventoryHost(db_basedir=inventory_dir,
                                              action="del", hosts=hosts)
            invHost.run()
        except e:
            os.rmdir(invalid_hostfile)
            raise e

    # InventoryTag
    @unittest.expectedFailure
    def test_inventory_tag_init(self):
        invTag = inventory.InventoryTag(db_basedir=inventory_dir,
                                        action="add")

    def test_inventory_tag_stdin_multiple_hosts(self):
        try:
            invTag = inventory.InventoryTag(db_basedir=inventory_dir,
                                            action="add", tagfile="-",
                                            hosts=("host1", "host2",))
        except e:
            self.fail()

    def test_inventory_tag_stdin_hostfile(self):
        try:
            invTag = inventory.InventoryTag(db_basedir=inventory_dir,
                                            action="add", tagfile="-",
                                            hostfile="hosts")
        except e:
            self.fail()

    @unittest.expectedFailure
    def test_inventory_tag_stdin_both(self):
        invTag = inventory.InventoryTag(db_basedir=inventory_dir,
                                        action="add", tagfile="-",
                                        hostfile="-")

    def test_inventory_tag_add_for_all_hosts(self):
        tags = ("spam-spam-spam", "spam-spam-eggs",)
        tagsf = ("spam-spam-spam-eggs", "spam-spam-eggs-spam",)
        tagfile = op.join(fixtures, "tags")
        with open(tagfile, "w") as f:
            for x in tagsf:
                f.write("{}\n".format(x))
        invTag = inventory.InventoryTag(db_basedir=inventory_dir,
                                        action="add", tags=tags,
                                        tagfile=tagfile)
        invTag.run()
        invList = inventory.InventoryList(db_basedir=inventory_dir)
        failed = False
        for host, taglist in invList.entries():
            for x in tagsf + tags:
                if x not in taglist:
                    failed = True
                    break
            if failed:
                break
        os.remove(tagfile)
        if failed:
            self.fail()

    def test_inventory_tag_add(self):
        tags = ("spam-spam-spam", "spam-spam-eggs",)
        tagsf = ("spam-spam-spam-eggs", "spam-spam-eggs-spam",)
        hosts = ("loadbalancer1", "loadbalancer2", "shell2",)
        hostsf = ("web2", "web3",)
        tagfile = op.join(fixtures, "tags")
        with open(tagfile, "w") as f:
            for x in tagsf:
                f.write("{}\n".format(x))
        hostfile = op.join(fixtures, "hosts")
        with open(hostfile, "w") as f:
            for x in hostsf:
                f.write("{}\n".format(x))
        invTag = inventory.InventoryTag(db_basedir=inventory_dir,
                                        action="add", tags=tags,
                                        tagfile=tagfile, hosts=hosts,
                                        hostfile=hostfile)
        invTag.run()
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          hosts=hosts + hostsf)
        failed = False
        for host, taglist in invList.entries():
            if host not in hosts + hostsf:
                failed = True
                break
            for x in tagsf + tags:
                if x not in taglist:
                    failed = True
                    break
            if failed:
                break
        os.remove(tagfile)
        os.remove(hostfile)
        if failed:
            self.fail()

    def test_inventory_tag_del_for_all_hosts(self):
        tags = ("all",)
        tagsf = ("charge",)
        tagfile = op.join(fixtures, "tags")
        with open(tagfile, "w") as f:
            for x in tagsf:
                f.write("{}\n".format(x))
        invTag = inventory.InventoryTag(db_basedir=inventory_dir,
                                        action="del", tags=tags,
                                        tagfile=tagfile)
        invTag.run()
        invList = inventory.InventoryList(db_basedir=inventory_dir)
        failed = False
        for host, taglist in invList.entries():
            for x in tagsf + tags:
                if x in taglist:
                    failed = True
                    break
            if failed:
                break
        os.remove(tagfile)
        if failed:
            self.fail()

    def test_inventory_tag_del(self):
        tags = ("europe", "africa",)
        tagsf = ("free", )
        hosts = ("loadbalancer1", "loadbalancer2", "shell2",)
        hostsf = ("web2", "web3",)
        tagfile = op.join(fixtures, "tags")
        with open(tagfile, "w") as f:
            for x in tagsf:
                f.write("{}\n".format(x))
        hostfile = op.join(fixtures, "hosts")
        with open(hostfile, "w") as f:
            for x in hostsf:
                f.write("{}\n".format(x))
        invTag = inventory.InventoryTag(db_basedir=inventory_dir,
                                        action="del", tags=tags,
                                        tagfile=tagfile, hosts=hosts,
                                        hostfile=hostfile)
        invTag.run()
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          hosts=hosts + hostsf)
        failed = False
        for host, taglist in invList.entries():
            if host not in hosts + hostsf:
                failed = True
                break
            for x in tagsf + tags:
                if x in taglist:
                    failed = True
                    break
            if failed:
                break
        os.remove(tagfile)
        os.remove(hostfile)
        if failed:
            self.fail()

    def test_inventory_tag_del_all_tags(self):
        hosts = ("web3", "shell1",)
        hostsf = ("shell2", "loadbalancer1",)
        hostfile = op.join(fixtures, "hosts")
        with open(hostfile, "w") as f:
            for x in hostsf:
                f.write("{}\n".format(x))
        invHost = inventory.InventoryHost(db_basedir=inventory_dir,
                                          action="del", all=True,
                                          hosts=hosts, hostfile=hostfile)
        invHost.run()
        invList = inventory.InventoryList(db_basedir=inventory_dir,
                                          hosts=hosts + hostsf)
        for host, htags in invList.entries():
            self.assertEqual(htags, ())
        os.remove(hostfile)


if __name__ == "__main__":
    unittest.main()
