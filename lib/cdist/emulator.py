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
    if '__debug' in os.environ:
        logging.root.setLevel(logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)

    global_path = os.environ['__global']
    object_source = os.environ['__cdist_manifest']
    type_name = os.path.basename(argv[0])

    object_base_path = os.path.join(global_path, "object")
    type_base_path = os.environ['__cdist_type_base_path']
    cdist_type = core.Type(type_base_path, type_name)

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

    # Prefix output by object_self
    logformat = '%%(levelname)s: %s: %%(message)s' % cdist_object.path
    logging.basicConfig(format=logformat)

    # FIXME: verify object id
    log.debug(args)

    # Create object with given parameters
    parameters = vars(args)
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
        log.debug("%s:Writing requirements: %s" % (cdist_object.path, requirements))
        cdist_object.requirements.extend(requirements.split(" "))

    # Record / Append source
    # FIXME: source should be list
    cdist_object.source.append(object_source)

    log.debug("Finished %s %s" % (cdist_object.path, parameters))
