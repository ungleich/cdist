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
import cdist.path

log = logging.getLogger(__name__)

def run(argv):
    """Emulate type commands (i.e. __file and co)"""
    type            = os.path.basename(argv[0])
    type_dir        = os.path.join(os.environ['__cdist_type_base_dir'], type)
    param_dir       = os.path.join(type_dir, "parameter")
    global_dir      = os.environ['__global']
    object_source   = os.environ['__cdist_manifest']

    if '__debug' in os.environ:
        logging.root.setLevel(logging.DEBUG)

    parser = argparse.ArgumentParser(add_help=False)

    # Setup optional parameters
    for parameter in cdist.path.file_to_list(os.path.join(param_dir, "optional")):
        argument = "--" + parameter
        parser.add_argument(argument, action='store', required=False)

    # Setup required parameters
    for parameter in cdist.path.file_to_list(os.path.join(param_dir, "required")):
        argument = "--" + parameter
        parser.add_argument(argument, action='store', required=True)

    # Setup positional parameter, if not singleton

    if not os.path.isfile(os.path.join(type_dir, "singleton")):
        parser.add_argument("object_id", nargs=1)

    # And finally verify parameter
    args = parser.parse_args(argv[1:])

    # Setup object_id
    if os.path.isfile(os.path.join(type_dir, "singleton")):
        object_id = "singleton"
    else:
        object_id = args.object_id[0]
        del args.object_id

        # FIXME: / hardcoded - better portable solution available?
        if object_id[0] == '/':
            object_id = object_id[1:]

    # FIXME: verify object id
    log.debug(args)

    object_dir = os.path.join(global_dir, "object", type,
                            object_id, cdist.path.DOT_CDIST)
    param_out_dir = os.path.join(object_dir, "parameter")

    object_source_file = os.path.join(object_dir, "source")

    if os.path.exists(param_out_dir):
        object_exists = True
        old_object_source_fd = open(object_source_file, "r")
        old_object_source = old_object_source_fd.readlines()
        old_object_source_fd.close()

    else:
        object_exists = False
        try:
            os.makedirs(param_out_dir, exist_ok=True)
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
    if "__require" in os.environ:
        requirements = os.environ['__require']
        print(object_id + ":Writing requirements: " + requirements)
        require_fd = open(os.path.join(object_dir, "require"), "a")
        require_fd.writelines(requirements.split(" "))
        require_fd.close()

    # Record / Append source
    source_fd = open(os.path.join(object_dir, "source"), "a")
    source_fd.writelines(object_source)
    source_fd.close()

    log.debug("Finished " + type + "/" + object_id + repr(params))


def link(exec_path, bin_dir, type_list):
    """Link type names to cdist-type-emulator"""
    source = os.path.abspath(exec_path)
    for type in type_list:
        destination = os.path.join(bin_dir, type)
        log.debug("Linking %s to %s", source, destination)
        os.symlink(source, destination)
