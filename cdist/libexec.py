import os
import os.path
import cdist.argparse
import subprocess
import sys


libexec_delimiter = '-'
libexec_prefix = 'cdist' + libexec_delimiter
libexec_path = os.path.abspath(
    os.path.join(os.path.dirname(cdist.__file__), 'conf', 'libexec'))


def scan():
    if os.path.isdir(libexec_path):
        with os.scandir(libexec_path) as it:
            for entry in it:
                if (entry.name.startswith(libexec_prefix) and
                        entry.is_file() and
                        os.access(entry.path, os.X_OK)):
                    start = entry.name.find(libexec_delimiter) + 1
                    yield entry.name[start:]


def is_libexec_command(name):
    for x in scan():
        if name == x:
            return True
    return False


def create_parsers(parser, parent_parser):
    for name in scan():
        parser[name] = parent_parser.add_parser(name, add_help=False)


def run(name, argv):
    lib_name = libexec_prefix + name
    lib_path = os.path.join(libexec_path, lib_name)
    args = [lib_path, ]
    args.extend(argv)
    try:
        subprocess.check_call(args)
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
