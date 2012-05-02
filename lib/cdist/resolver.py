# -*- coding: utf-8 -*-
#
# 2011 Steven Armstrong (steven-cdist at armstrong.cc)
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
import itertools
import fnmatch

import cdist

log = logging.getLogger(__name__)


class CircularReferenceError(cdist.Error):
    def __init__(self, cdist_object, required_object):
        self.cdist_object = cdist_object
        self.required_object = required_object

    def __str__(self):
        return 'Circular reference detected: %s -> %s' % (self.cdist_object.name, self.required_object.name)


class RequirementNotFoundError(cdist.Error):
    def __init__(self, requirement):
        self.requirement = requirement

    def __str__(self):
        return 'Requirement could not be found: %s' % self.requirement


class DependencyResolver(object):
    """Cdist's dependency resolver.

    Usage:
    resolver = DependencyResolver(list_of_objects)
    from pprint import pprint
    pprint(resolver.graph)

    for cdist_object in resolver:
        do_something_with(cdist_object)

    """
    def __init__(self, objects, logger=None):
        self.objects = list(objects) # make sure we store as list, not generator
        self._object_index = dict((o.name, o) for o in self.objects)
        self._graph = None
        self.log = logger or log

    @property
    def graph(self):
        """Build the dependency graph.

        Returns a dict where the keys are the object names and the values are
        lists of all dependencies including the key object itself.
        """
        if self._graph is None:
            graph = {}
            self.preprocess_requirements()
            for o in self.objects:
                resolved = []
                unresolved = []
                self.resolve_object_dependencies(o, resolved, unresolved)
                graph[o.name] = resolved
            self._graph = graph
        return self._graph

    def preprocess_requirements(self):
        """Find all autorequire dependencies and convert them to be just requirements.
        """
        for cdist_object in self.objects:
            if cdist_object.autorequire:
                # objects which this cdist_object (parent) defined in it's type manifest,
                # and therefor have an implicit automatic dependency,
                # shall inherit all requirements that it's parent has
                for auto_requirement in self.find_requirements_by_name(cdist_object.autorequire):
                    for requirement in cdist_object.requirements:
                        if requirement not in auto_requirement.requirements:
                            auto_requirement.requirements.append(requirement)

    def find_requirements_by_name(self, requirements):
        """Takes a list of requirement patterns and returns a list of matching object instances.

        Patterns are expected to be Unix shell-style wildcards for use with fnmatch.filter.

        find_requirements_by_name(['__type/object_id', '__other_type/*']) -> 
            [<Object __type/object_id>, <Object __other_type/any>, <Object __other_type/match>]
        """
        object_names = self._object_index.keys()
        for pattern in requirements:
            found = False
            for requirement in fnmatch.filter(object_names, pattern):
                found = True
                yield self._object_index[requirement]
            if not found:
                # FIXME: get rid of the singleton object_id, it should be invisible to the code -> hide it in Object
                singleton = os.path.join(pattern, 'singleton')
                if singleton in self._object_index:
                    yield self._object_index[singleton]
                else:
                    raise RequirementNotFoundError(pattern)

    def resolve_object_dependencies(self, cdist_object, resolved, unresolved):
        """Resolve all dependencies for the given cdist_object and store them
        in the list which is passed as the 'resolved' arguments.

        e.g.
        resolved = []
        unresolved = []
        resolve_object_dependencies(some_object, resolved, unresolved)
        print("Dependencies for %s: %s" % (some_object, resolved))
        """
        self.log.debug('Resolving dependencies for: %s' % cdist_object.name)
        try:
            unresolved.append(cdist_object)
            for required_object in self.find_requirements_by_name(cdist_object.requirements):
                self.log.debug("Object %s requires %s", cdist_object, required_object)
                if required_object not in resolved:
                    if required_object in unresolved:
                        raise CircularReferenceError(cdist_object, required_object)
                    self.resolve_object_dependencies(required_object, resolved, unresolved)
            resolved.append(cdist_object)
            unresolved.remove(cdist_object)
        except RequirementNotFoundError as e:
            raise cdist.CdistObjectError(cdist_object, "requires non-existing " + e.requirement)

    def __iter__(self):
        """Iterate over all unique objects while resolving dependencies.
        """
        iterable = itertools.chain(*self.graph.values())
        # Keep record of objects that have already been seen
        seen = set()
        seen_add = seen.add
        for cdist_object in itertools.filterfalse(seen.__contains__, iterable):
            seen_add(cdist_object)
            yield cdist_object
