# -*- coding: utf-8 -*-
#
# 2011 Nico Schottelius (nico-cdist at schottelius.org)
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

import argparse
import logging
import os

import cdist
from cdist import core

log = logging.getLogger(__name__)

def run(argv):
    """Emulate type commands (i.e. __file and co)"""
    global_path = os.environ['__global']
    object_source = os.environ['__cdist_manifest']
    target_host = os.environ['__target_host']
    type_name = os.path.basename(argv[0])

    # Logsetup - FIXME: add object_fq as soon as setup!
    #id = target_host + ": " + cdist_type + '/' + object_id 
    id = target_host + ": "
    # logformat = '%(levelname)s: ' + target_host + ": " + cdist_type + '/' + object_id + ': %(message)s'
    logformat = '%(levelname)s: ' + id + ': %(message)s'
    logging.basicConfig(format=logformat)

    if '__debug' in os.environ:
        logging.root.setLevel(logging.DEBUG)
    else:
        logging.root.setLevel(logging.INFO)

    object_base_path = os.path.join(global_path, "object")
    type_base_path = os.environ['__cdist_type_base_path']
    cdist_type = core.Type(type_base_path, type_name)

    if '__install' in os.environ:
        if not cdist_type.is_install:
            log.debug("Running in install mode, ignoring non install type")
            return True

    parser = argparse.ArgumentParser(add_help=False)

    for parameter in cdist_type.optional_parameters:
        argument = "--" + parameter
        parser.add_argument(argument, action='store', required=False)
    for parameter in cdist_type.required_parameters:
        argument = "--" + parameter
        parser.add_argument(argument, action='store', required=True)

    # If not singleton support one positional parameter
    if not cdist_type.is_singleton:
        parser.add_argument("object_id", nargs=1)

    # And finally verify parameter
    args = parser.parse_args(argv[1:])

    # Setup object_id
    if cdist_type.is_singleton:
        object_id = "singleton"
    else:
        object_id = args.object_id[0]
        del args.object_id

        # strip leading slash from object_id
        object_id = object_id.lstrip('/')

    # Instantiate the cdist object whe are defining
    cdist_object = core.Object(cdist_type, object_base_path, object_id)

    # FIXME: verify object id
    log.debug('#### emulator args: %s' % args)

    # Create object with given parameters
    parameters = {}
    for key,value in vars(args).items():
        if value is not None:
            parameters[key] = value
    
    if cdist_object.exists:
        if cdist_object.parameters != parameters:
            raise cdist.Error("Object %s already exists with conflicting parameters:\n%s: %s\n%s: %s"
                % (cdist_object, " ".join(cdist_object.source), cdist_object.parameters, object_source, parameters)
            )
    else:
        cdist_object.create()
        cdist_object.parameters = parameters

    # Record requirements
    if "require" in os.environ:
        requirements = os.environ['require']
        for requirement in requirements.split(" "):
            requirement_parts = requirement.split(os.sep, 1)
            requirement_parts.reverse()
            requirement_type_name = requirement_parts.pop()
            try:
                requirement_object_id = requirement_parts.pop()
            except IndexError:
                # no object id, must be singleton
                requirement_object_id = 'singleton'
            if requirement_object_id.startswith('/'):
                raise core.IllegalObjectIdError(requirement_object_id, 'object_id may not start with /')
            log.debug("Recording requirement: %s -> %s" % (cdist_object.path, requirement))
            cdist_object.requirements.append(rement_object_id)

    # Record / Append source
    cdist_object.source.append(object_source)

    log.debug("Finished %s %s" % (cdist_object.path, parameters))
