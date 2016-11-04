import os
import os.path
import sys
import inspect
import argparse
import cdist
import logging


_PREOS_CALL = "commandline"
_PREOS_NAME = "preos_name"
_PREOS_EXCLUDE = "preos_exclude"
_PLUGINS_DIR = "preos"
_PLUGINS_PATH = [os.path.join(os.path.dirname(__file__), _PLUGINS_DIR), ]
sys.path.extend(_PLUGINS_PATH)


logging.setLoggerClass(cdist.log.Log)
logging.basicConfig(format='%(levelname)s: %(message)s')
log = logging.getLogger("PreOS")


def preos_plugin(obj):
    if not hasattr(obj, _PREOS_EXCLUDE):
        exclude = False
    else:
        exclude = getattr(obj, _PREOS_EXCLUDE)

    if not exclude and hasattr(obj, _PREOS_CALL):
        yield obj


def find_dir_plugins(dir):
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


def find_plugins():
    for dir in _PLUGINS_PATH:
        yield from find_dir_plugins(dir)


def find_preoses():
    preoses = {}
    for preos in find_plugins():
        if hasattr(preos, _PREOS_NAME):
            preos_name = preos.preos_name
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
        import cdist.argparse

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
            func(argv[2:])
        else:
            log.error("Unknown preos: {}, available preoses: {}".format(
                preos_name, set(cls.preoses.keys())))
