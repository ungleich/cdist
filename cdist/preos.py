import os
import os.path
import sys
import inspect
import argparse
import cdist
import logging
import cdist.argparse
import cdist.configuration
import cdist.exec.util as util


_PREOS_CALL = "commandline"
_PREOS_NAME = "_preos_name"
_PREOS_MARKER = "_cdist_preos"
_PLUGINS_DIR = "preos"
_PLUGINS_PATH = [os.path.join(os.path.dirname(__file__), _PLUGINS_DIR), ]
log = logging.getLogger("PreOS")


def extend_plugins_path(dirs):
    for dir in dirs:
        preos_dir = os.path.expanduser(os.path.join(dir, "preos"))
        if os.path.isdir(preos_dir):
            _PLUGINS_PATH.append(preos_dir)


def preos_plugin(obj):
    """It is preos if _PREOS_MARKER is True and has _PREOS_CALL."""
    if hasattr(obj, _PREOS_MARKER):
        is_preos = getattr(obj, _PREOS_MARKER)
    else:
        is_preos = False

    if is_preos and hasattr(obj, _PREOS_CALL):
        yield obj


def scan_preos_dir_plugins(dir):
    for fname in os.listdir(dir):
        if os.path.isfile(os.path.join(dir, fname)):
            fname = os.path.splitext(fname)[0]
        module_name = fname
        try:
            module = __import__(module_name)
            yield from preos_plugin(module)
            clsmembers = inspect.getmembers(module, inspect.isclass)
            for cm in clsmembers:
                c = cm[1]
                yield from preos_plugin(c)
        except ImportError as e:
            log.warning("Cannot import '{}': {}".format(module_name, e))


def find_preos_plugins():
    for dir in _PLUGINS_PATH:
        yield from scan_preos_dir_plugins(dir)


def find_preoses():
    preoses = {}
    for preos in find_preos_plugins():
        if hasattr(preos, _PREOS_NAME):
            preos_name = getattr(preos, _PREOS_NAME)
        else:
            preos_name = preos.__name__.lower()
        preoses[preos_name] = preos
    return preoses


def check_root():
    if os.geteuid() != 0:
        raise cdist.Error("Must be run with root privileges")


def get_available_preoses_string(cls):
    preoses = ['    - {}'.format(x) for x in sorted(set(cls.preoses))]
    return "Available PreOS-es:\n{}".format("\n".join(preoses))


class PreOS:
    preoses = None

    @classmethod
    def commandline(cls, argv):
        cdist_parser = cdist.argparse.get_parsers()
        parser = argparse.ArgumentParser(
            description="Create PreOS", prog="cdist preos",
            parents=[cdist_parser['loglevel'], ])
        parser.add_argument('preos', help='PreOS to create',
                            nargs='?', default=None)
        parser.add_argument('-c', '--conf-dir',
                            help=('Add configuration directory (one that '
                                  'contains "preos" subdirectory)'),
                            action='append')
        parser.add_argument('-g', '--config-file',
                            help='Use specified custom configuration file.',
                            dest="config_file", required=False)
        parser.add_argument('-L', '--list-preoses',
                            help='List available PreOS-es',
                            action='store_true', default=False)
        parser.add_argument('remainder_args', nargs=argparse.REMAINDER)
        args = parser.parse_args(argv[1:])
        cdist.argparse.handle_loglevel(args)
        log.debug("preos args : {}".format(args))

        conf_dirs = util.resolve_conf_dirs_from_config_and_args(args)

        extend_plugins_path(conf_dirs)
        sys.path.extend(_PLUGINS_PATH)
        cls.preoses = find_preoses()

        if args.list_preoses or not args.preos:
            print(get_available_preoses_string(cls))
            sys.exit(0)

        preos_name = args.preos
        if preos_name in cls.preoses:
            preos = cls.preoses[preos_name]
            func = getattr(preos, _PREOS_CALL)
            if inspect.ismodule(preos):
                func_args = [preos, args.remainder_args, ]
            else:
                func_args = [args.remainder_args, ]
            log.info("Running preos : {}".format(preos_name))
            func(*func_args)
        else:
            raise cdist.Error(
                "Invalid PreOS {}. {}".format(
                    preos_name, get_available_preoses_string(cls)))
