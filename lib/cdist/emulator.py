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

log = logging.getLogger(__name__)

def run(argv):
    """Emulate type commands (i.e. __file and co)"""
    cdist_type      = os.path.basename(argv[0])
    type_path       = os.path.join(os.environ['__cdist_type_base_path'], cdist_type)
    param_path      = os.path.join(type_path, "parameter")
    global_path     = os.environ['__global']
    object_source   = os.environ['__cdist_manifest']

    if '__debug' in os.environ:
        logging.root.setLevel(logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)

    parser = argparse.ArgumentParser(add_help=False)

    for parameter in cdist.file_to_list(os.path.join(param_path, "optional")):
        argument = "--" + parameter
        parser.add_argument(argument, action='store', required=False)
    for parameter in cdist.file_to_list(os.path.join(param_path, "required")):
        argument = "--" + parameter
        parser.add_argument(argument, action='store', required=True)

    # If not singleton support one positional parameter
    if not os.path.isfile(os.path.join(type_path, "singleton")):
        parser.add_argument("object_id", nargs=1)

    # And finally verify parameter
    args = parser.parse_args(argv[1:])

    # Setup object_id
    if os.path.isfile(os.path.join(type_path, "singleton")):
        object_id = "singleton"
    else:
        object_id = args.object_id[0]
        del args.object_id

        # FIXME: / hardcoded - better portable solution available?
        if object_id[0] == '/':
            object_id = object_id[1:]

    # Prefix output by object_self
    logformat = '%(levelname)s: ' + cdist_type + '/' + object_id + ': %(message)s'
    logging.basicConfig(format=logformat)

    # FIXME: verify object id
    log.debug(args)

    object_path = os.path.join(global_path, "object", cdist_type,
                            object_id, cdist.DOT_CDIST)
    log.debug("Object output dir = " + object_path)

    param_out_dir = os.path.join(object_path, "parameter")

    object_source_file = os.path.join(object_path, "source")

    if os.path.exists(object_path):
        object_exists = True
        old_object_source_fd = open(object_source_file, "r")
        old_object_source = old_object_source_fd.readlines()
        old_object_source_fd.close()

    else:
        object_exists = False
        try:
            os.makedirs(object_path, exist_ok=False)
            log.debug("Object param dir = " + param_out_dir)
            os.makedirs(param_out_dir, exist_ok=False)
        except OSError as error:
            raise cdist.Error(param_out_dir + ": " + error.args[1])

    # Record parameter
    params = vars(args)
    for param in params:
        value = getattr(args, param)
        if value:
            file = os.path.join(param_out_dir, param)
            log.debug(file + "<-" + param + " = " + value)

            # Already exists, verify all parameter are the same
            if object_exists:
                if not os.path.isfile(file):
                    raise cdist.Error("New parameter \"" +
                        param + "\" specified, aborting\n" +
                        "Source = " +
                        " ".join(old_object_source)
                        + " new =" + object_source)
                else:
                    param_fd = open(file, "r")
                    value_old = param_fd.readlines()
                    param_fd.close()
                    
                    if(value_old[0] != value):
                        raise cdist.Error("Parameter\"" + param +
                            "\" differs: " + " ".join(value_old) + " vs. " +
                            value +
                            "\nSource = " + " ".join(old_object_source)
                            + " new = " + object_source)
            else:
                param_fd = open(file, "w")
                param_fd.writelines(value)
                param_fd.close()

    # Record requirements
    if "require" in os.environ:
        requirements = os.environ['require']
        log.debug(object_id + ":Writing requirements: " + requirements)
        require_fd = open(os.path.join(object_path, "require"), "a")
        require_fd.write(requirements.replace(" ","\n"))
        require_fd.close()

    # Record / Append source
    source_fd = open(os.path.join(object_path, "source"), "a")
    source_fd.writelines(object_source)
    source_fd.close()

    log.debug("Finished " + cdist_type + "/" + object_id + repr(params))
