import os
import os.path
import sys
import inspect
import argparse
import cdist
import logging


_PREOS_CALL = "commandline"
_PREOS_NAME = "_preos_name"
_PREOS_MARKER = "_cdist_preos"
_PLUGINS_DIR = "preos"
_PLUGINS_PATH = [os.path.join(os.path.dirname(__file__), _PLUGINS_DIR), ]
cdist_home = cdist.home_dir()
if cdist_home:
    cdist_home_preos = os.path.join(cdist_home, "preos")
    if os.path.isdir(cdist_home_preos):
        _PLUGINS_PATH.append(cdist_home_preos)
sys.path.extend(_PLUGINS_PATH)


log = logging.getLogger("PreOS")


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


class PreOS(object):
    preoses = None

    @classmethod
    def commandline(cls, argv):

        if not cls.preoses:
            cls.preoses = find_preoses()

        parser = argparse.ArgumentParser(
            description="Create PreOS", prog="cdist preos")
        parser.add_argument('preos', help='PreOS to create, one of: {}'.format(
            set(cls.preoses)))
        args = parser.parse_args(argv[1:2])

        preos_name = args.preos
        if preos_name in cls.preoses:
            preos = cls.preoses[preos_name]
            func = getattr(preos, _PREOS_CALL)
            if inspect.ismodule(preos):
                func_args = [preos, argv[2:], ]
            else:
                func_args = [argv[2:], ]
            log.info("Running preos : {}".format(preos_name))
            func(*func_args)
        else:
            log.error("Unknown preos: {}, available preoses: {}".format(
                preos_name, set(cls.preoses.keys())))
