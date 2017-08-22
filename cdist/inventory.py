#!/usr/bin/env python3
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

import cdist
import logging
import os
import os.path
import itertools
import sys
import cdist.configuration
from cdist.hostsource import hostfile_process_line

DIST_INVENTORY_DB_NAME = "inventory"

dist_inventory_db = os.path.abspath(os.path.join(
    os.path.dirname(cdist.__file__), DIST_INVENTORY_DB_NAME))


def determine_default_inventory_dir(args, configuration):
    # The order of inventory dir setting by decreasing priority
    # 1. inventory_dir from configuration
    # 2. ~/.cdist/inventory if HOME env var is set
    # 3. distribution inventory directory
    inventory_dir_set = False
    if 'inventory_dir' in configuration:
        val = configuration['inventory_dir']
        if val:
            args.inventory_dir = val
            inventory_dir_set = True
    if not inventory_dir_set:
        home = cdist.home_dir()
        if home:
            args.inventory_dir = os.path.join(home, DIST_INVENTORY_DB_NAME)
        else:
            args.inventory_dir = dist_inventory_db


def contains_all(big, little):
    """Return True if big contains all elements from little,
       False otherwise.
    """
    return set(little).issubset(set(big))


def contains_any(big, little):
    """Return True if big contains any element from little,
       False otherwise.
    """
    for x in little:
        if x in big:
            return True
    return False


def check_always_true(x, y):
    return True


def rstrip_nl(s):
    '''str.rstrip "\n" from s'''
    return str.rstrip(s, "\n")


class Inventory(object):
    """Inventory main class"""

    def __init__(self, db_basedir=dist_inventory_db, configuration=None):
        self.db_basedir = db_basedir
        if configuration:
            self.configuration = configuration
        else:
            self.configuration = {}
        self.log = logging.getLogger("inventory")
        self.init_db()

    def init_db(self):
        self.log.trace("Init db: {}".format(self.db_basedir))
        if not os.path.exists(self.db_basedir):
            os.makedirs(self.db_basedir, exist_ok=True)
        elif not os.path.isdir(self.db_basedir):
            raise cdist.Error(("Invalid inventory db basedir \'{}\',"
                               " must be a directory").format(self.db_basedir))

    @staticmethod
    def strlist_to_list(slist):
        if slist:
            result = [x for x in slist.split(',') if x]
        else:
            result = []
        return result

    def _input_values(self, source):
        """Yield input values from source.
           Source can be a sequence or filename (stdin if '-').
           In case of filename each line represents one input value.
        """
        if isinstance(source, str):
            import fileinput
            try:
                with fileinput.FileInput(files=(source)) as f:
                    for x in f:
                        result = hostfile_process_line(x, strip_func=rstrip_nl)
                        if result:
                            yield result
            except (IOError, OSError) as e:
                raise cdist.Error("Error reading from \'{}\'".format(
                    source))
        else:
            if source:
                for x in source:
                    if x:
                        yield x

    def _host_path(self, host):
        hostpath = os.path.join(self.db_basedir, host)
        return hostpath

    def _all_hosts(self):
        return os.listdir(self.db_basedir)

    def _check_host(self, hostpath):
        if not os.path.exists(hostpath):
            return False
        else:
            if not os.path.isfile(hostpath):
                raise cdist.Error(("Host path \'{}\' exists, but is not"
                                   " a valid file").format(hostpath))
        return True

    def _read_host_tags(self, hostpath):
        result = set()
        with open(hostpath, "rt") as f:
            for tag in f:
                tag = tag.rstrip("\n")
                if tag:
                    result.add(tag)
        return result

    def _get_host_tags(self, host):
        hostpath = self._host_path(host)
        if self._check_host(hostpath):
            return self._read_host_tags(hostpath)
        else:
            return None

    def _write_host_tags(self, host, tags):
        hostpath = self._host_path(host)
        if self._check_host(hostpath):
            with open(hostpath, "wt") as f:
                for tag in tags:
                    f.write("{}\n".format(tag))
            return True
        else:
            return False

    @classmethod
    def commandline(cls, args):
        """Manipulate inventory db"""
        log = logging.getLogger("inventory")
        if 'taglist' in args:
            args.taglist = cls.strlist_to_list(args.taglist)

        cfg = cdist.configuration.Configuration(args)
        configuration = cfg.get_config(section='GLOBAL')
        determine_default_inventory_dir(args, configuration)

        log.debug("Using inventory: {}".format(args.inventory_dir))
        log.trace("Inventory args: {}".format(vars(args)))
        log.trace("Inventory command: {}".format(args.subcommand))

        if args.subcommand == "list":
            c = InventoryList(hosts=args.host, istag=args.tag,
                              hostfile=args.hostfile,
                              db_basedir=args.inventory_dir,
                              list_only_host=args.list_only_host,
                              has_all_tags=args.has_all_tags,
                              configuration=configuration)
        elif args.subcommand == "add-host":
            c = InventoryHost(hosts=args.host, hostfile=args.hostfile,
                              db_basedir=args.inventory_dir,
                              configuration=configuration)
        elif args.subcommand == "del-host":
            c = InventoryHost(hosts=args.host, hostfile=args.hostfile,
                              all=args.all, db_basedir=args.inventory_dir,
                              action="del", configuration=configuration)
        elif args.subcommand == "add-tag":
            c = InventoryTag(hosts=args.host, tags=args.taglist,
                             hostfile=args.hostfile, tagfile=args.tagfile,
                             db_basedir=args.inventory_dir,
                             configuration=configuration)
        elif args.subcommand == "del-tag":
            c = InventoryTag(hosts=args.host, tags=args.taglist,
                             hostfile=args.hostfile, tagfile=args.tagfile,
                             all=args.all, db_basedir=args.inventory_dir,
                             action="del", configuration=configuration)
        else:
            raise cdist.Error("Unknown inventory command \'{}\'".format(
                        args.subcommand))
        c.run()


class InventoryList(Inventory):
    def __init__(self, hosts=None, istag=False, hostfile=None,
                 list_only_host=False, has_all_tags=False,
                 db_basedir=dist_inventory_db, configuration=None):
        super().__init__(db_basedir, configuration)
        self.hosts = hosts
        self.istag = istag
        self.hostfile = hostfile
        self.list_only_host = list_only_host
        self.has_all_tags = has_all_tags

    def _print(self, host, tags):
        if self.list_only_host:
            print("{}".format(host))
        else:
            print("{} {}".format(host, ",".join(sorted(tags))))

    def _do_list(self, it_tags, it_hosts, check_func):
        if (it_tags is not None):
            param_tags = set(it_tags)
            self.log.trace("param_tags: {}".format(param_tags))
        else:
            param_tags = set()
        for host in it_hosts:
            self.log.trace("host: {}".format(host))
            tags = self._get_host_tags(host)
            if tags is None:
                self.log.debug("Host \'{}\' not found, skipped".format(host))
                continue
            self.log.trace("tags: {}".format(tags))
            if check_func(tags, param_tags):
                yield host, tags

    def entries(self):
        if not self.hosts and not self.hostfile:
            self.log.trace("Listing all hosts")
            it_hosts = self._all_hosts()
            it_tags = None
            check_func = check_always_true
        else:
            it = itertools.chain(self._input_values(self.hosts),
                                 self._input_values(self.hostfile))
            if self.istag:
                self.log.trace("Listing by tag(s)")
                it_hosts = self._all_hosts()
                it_tags = it
                if self.has_all_tags:
                    check_func = contains_all
                else:
                    check_func = contains_any
            else:
                self.log.trace("Listing by host(s)")
                it_hosts = it
                it_tags = None
                check_func = check_always_true
        for host, tags in self._do_list(it_tags, it_hosts, check_func):
            yield host, tags

    def host_entries(self):
        for host, tags in self.entries():
            yield host

    def run(self):
        for host, tags in self.entries():
            self._print(host, tags)


class InventoryHost(Inventory):
    def __init__(self, hosts=None, hostfile=None,
                 db_basedir=dist_inventory_db, all=False, action="add",
                 configuration=None):
        super().__init__(db_basedir, configuration)
        self.actions = ("add", "del")
        if action not in self.actions:
            raise cdist.Error("Invalid action \'{}\', valid actions are:"
                              " {}\n".format(action, self.actions.keys()))
        self.action = action
        self.hosts = hosts
        self.hostfile = hostfile
        self.all = all

        if not self.hosts and not self.hostfile:
            self.hostfile = "-"

    def _new_hostpath(self, hostpath):
        # create empty file
        with open(hostpath, "w"):
            pass

    def _action(self, host):
        if self.action == "add":
            self.log.debug("Adding host \'{}\'".format(host))
        elif self.action == "del":
            self.log.debug("Deleting host \'{}\'".format(host))
        hostpath = self._host_path(host)
        self.log.trace("hostpath: {}".format(hostpath))
        if self.action == "add" and not os.path.exists(hostpath):
                self._new_hostpath(hostpath)
        else:
            if not os.path.isfile(hostpath):
                raise cdist.Error(("Host path \'{}\' is"
                                   " not a valid file").format(hostpath))
            if self.action == "del":
                os.remove(hostpath)

    def run(self):
        if self.action == "del" and self.all:
            self.log.trace("Doing for all hosts")
            it = self._all_hosts()
        else:
            self.log.trace("Doing for specified hosts")
            it = itertools.chain(self._input_values(self.hosts),
                                 self._input_values(self.hostfile))
        for host in it:
            self._action(host)


class InventoryTag(Inventory):
    def __init__(self, hosts=None, tags=None, hostfile=None, tagfile=None,
                 db_basedir=dist_inventory_db, all=False, action="add",
                 configuration=None):
        super().__init__(db_basedir, configuration)
        self.actions = ("add", "del")
        if action not in self.actions:
            raise cdist.Error("Invalid action \'{}\', valid actions are:"
                              " {}\n".format(action, self.actions.keys()))
        self.action = action
        self.hosts = hosts
        self.tags = tags
        self.hostfile = hostfile
        self.tagfile = tagfile
        self.all = all

        if not self.hosts and not self.hostfile:
            self.allhosts = True
        else:
            self.allhosts = False
        if not self.tags and not self.tagfile:
            self.tagfile = "-"

        if self.hostfile == "-" and self.tagfile == "-":
            raise cdist.Error("Cannot read both, hosts and tags, from stdin")

    def _read_input_tags(self):
        self.input_tags = set()
        for tag in itertools.chain(self._input_values(self.tags),
                                   self._input_values(self.tagfile)):
            self.input_tags.add(tag)

    def _action(self, host):
        host_tags = self._get_host_tags(host)
        if host_tags is None:
            print("Host \'{}\' does not exist, skipping".format(host),
                  file=sys.stderr)
            return
        self.log.trace("existing host_tags: {}".format(host_tags))
        if self.action == "del" and self.all:
            host_tags = set()
        else:
            for tag in self.input_tags:
                if self.action == "add":
                    self.log.debug("Adding tag \'{}\' for host \'{}\'".format(
                        tag, host))
                    host_tags.add(tag)
                elif self.action == "del":
                    self.log.debug("Deleting tag \'{}\' for host "
                                   "\'{}\'".format(tag, host))
                    if tag in host_tags:
                        host_tags.remove(tag)
        self.log.trace("new host tags: {}".format(host_tags))
        if not self._write_host_tags(host, host_tags):
            self.log.trace("{} does not exist, skipped".format(host))

    def run(self):
        if self.allhosts:
            self.log.trace("Doing for all hosts")
            it = self._all_hosts()
        else:
            self.log.trace("Doing for specified hosts")
            it = itertools.chain(self._input_values(self.hosts),
                                 self._input_values(self.hostfile))
        if not(self.action == "del" and self.all):
            self._read_input_tags()
        for host in it:
            self._action(host)
