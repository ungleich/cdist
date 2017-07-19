import argparse
import cdist
import multiprocessing
import os
import logging
import collections


# set of beta sub-commands
BETA_COMMANDS = set(('install', ))
# set of beta arguments for sub-commands
BETA_ARGS = {
    'config': set(('jobs', )),
}
EPILOG = "Get cdist at http://www.nico.schottelius.org/software/cdist/"
# Parser others can reuse
parser = None


_verbosity_level_off = -2
_verbosity_level = {
    _verbosity_level_off: logging.OFF,
    -1: logging.ERROR,
    0: logging.WARNING,
    1: logging.INFO,
    2: logging.VERBOSE,
    3: logging.DEBUG,
    4: logging.TRACE,
}
# All verbosity levels above 4 are TRACE.
_verbosity_level = collections.defaultdict(
    lambda: logging.TRACE, _verbosity_level)


def add_beta_command(cmd):
    BETA_COMMANDS.add(cmd)


def add_beta_arg(cmd, arg):
    if cmd in BETA_ARGS:
        if arg not in BETA_ARGS[cmd]:
            BETA_ARGS[cmd].append(arg)
    else:
        BETA_ARGS[cmd] = set((arg, ))


def check_beta(args_dict):
    if 'beta' not in args_dict:
        args_dict['beta'] = False
    # Check only if beta is not enabled: if beta option is specified then
    # raise error.
    if not args_dict['beta']:
        cmd = args_dict['command']
        # first check if command is beta
        if cmd in BETA_COMMANDS:
            raise cdist.CdistBetaRequired(cmd)
        # then check if some command's argument is beta
        if cmd in BETA_ARGS:
            for arg in BETA_ARGS[cmd]:
                if arg in args_dict and args_dict[arg]:
                    raise cdist.CdistBetaRequired(cmd, arg)


def check_positive_int(value):
    import argparse

    try:
        val = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError(
                "{} is invalid int value".format(value))
    if val <= 0:
        raise argparse.ArgumentTypeError(
                "{} is invalid positive int value".format(val))
    return val


def get_parsers():
    global parser

    # Construct parser others can reuse
    if parser:
        return parser
    else:
        parser = {}
    # Options _all_ parsers have in common
    parser['loglevel'] = argparse.ArgumentParser(add_help=False)
    parser['loglevel'].add_argument(
            '-q', '--quiet',
            help='Quiet mode: disables logging, including WARNING and ERROR',
            action='store_true', default=False)
    parser['loglevel'].add_argument(
            '-v', '--verbose',
            help=('Increase the verbosity level. Every instance of -v '
                  'increments the verbosity level by one. Its default value '
                  'is 0 which includes ERROR and WARNING levels. '
                  'The levels, in order from the lowest to the highest, are: '
                  'ERROR (-1), WARNING (0), INFO (1), VERBOSE (2), DEBUG (3) '
                  'TRACE (4 or higher).'),
            action='count', default=0)

    parser['beta'] = argparse.ArgumentParser(add_help=False)
    parser['beta'].add_argument(
           '-b', '--beta',
           help=('Enable beta functionality. '
                 'Can also be enabled using CDIST_BETA env var.'),
           action='store_true', dest='beta',
           default='CDIST_BETA' in os.environ)

    # Main subcommand parser
    parser['main'] = argparse.ArgumentParser(
            description='cdist ' + cdist.VERSION, parents=[parser['loglevel']])
    parser['main'].add_argument(
            '-V', '--version', help='Show version', action='version',
            version='%(prog)s ' + cdist.VERSION)
    parser['sub'] = parser['main'].add_subparsers(
            title="Commands", dest="command")

    # Banner
    parser['banner'] = parser['sub'].add_parser(
            'banner', parents=[parser['loglevel']])
    parser['banner'].set_defaults(func=cdist.banner.banner)

    # Config
    parser['config_main'] = argparse.ArgumentParser(add_help=False)
    parser['config_main'].add_argument(
            '-C', '--cache-path-pattern',
            help=('Specify custom cache path pattern. It can also be set '
                  'by CDIST_CACHE_PATH_PATTERN environment variable. If '
                  'it is not set then default hostdir is used.'),
            dest='cache_path_pattern',
            default=os.environ.get('CDIST_CACHE_PATH_PATTERN'))
    parser['config_main'].add_argument(
            '-c', '--conf-dir',
            help=('Add configuration directory (can be repeated, '
                  'last one wins)'), action='append')
    parser['config_main'].add_argument(
           '-i', '--initial-manifest',
           help='path to a cdist manifest or \'-\' to read from stdin.',
           dest='manifest', required=False)
    parser['config_main'].add_argument(
           '-j', '--jobs', nargs='?',
           type=check_positive_int,
           help=('Specify the maximum number of parallel jobs. Global'
                 'explorers, object prepare and object run are supported'
                 '(currently in beta'),
           action='store', dest='jobs',
           const=multiprocessing.cpu_count())
    parser['config_main'].add_argument(
           '-n', '--dry-run',
           help='do not execute code', action='store_true')
    parser['config_main'].add_argument(
           '-o', '--out-dir',
           help='directory to save cdist output in', dest="out_path")

    # remote-copy and remote-exec defaults are environment variables
    # if set; if not then None - these will be futher handled after
    # parsing to determine implementation default
    parser['config_main'].add_argument(
           '--remote-copy',
           help='Command to use for remote copy (should behave like scp)',
           action='store', dest='remote_copy',
           default=os.environ.get('CDIST_REMOTE_COPY'))
    parser['config_main'].add_argument(
           '--remote-exec',
           help=('Command to use for remote execution '
                 '(should behave like ssh)'),
           action='store', dest='remote_exec',
           default=os.environ.get('CDIST_REMOTE_EXEC'))

    # Config
    parser['config_args'] = argparse.ArgumentParser(add_help=False)
    parser['config_args'].add_argument(
            'host', nargs='*', help='host(s) to operate on')
    parser['config_args'].add_argument(
            '-f', '--file',
            help=('Read specified file for a list of additional hosts to '
                  'operate on or if \'-\' is given, read stdin (one host per '
                  'line). If no host or host file is specified then, by '
                  'default, read hosts from stdin.'),
            dest='hostfile', required=False)
    parser['config_args'].add_argument(
           '-p', '--parallel',
           help='operate on multiple hosts in parallel',
           action='store_true', dest='parallel')
    parser['config_args'].add_argument(
           '-r', '--remote-out-dir',
           help='Directory to save cdist output in on the target host',
           dest="remote_out_path")
    parser['config_args'].add_argument(
           '-s', '--sequential',
           help='operate on multiple hosts sequentially (default)',
           action='store_false', dest='parallel')
    parser['config'] = parser['sub'].add_parser(
            'config', parents=[parser['loglevel'], parser['beta'],
                               parser['config_main'],
                               parser['config_args']])
    parser['config'].set_defaults(func=cdist.config.Config.commandline)

    # Install
    parser['install'] = parser['sub'].add_parser('install', add_help=False,
                                                 parents=[parser['config']])
    parser['install'].set_defaults(func=cdist.install.Install.commandline)

    # Shell
    parser['shell'] = parser['sub'].add_parser(
            'shell', parents=[parser['loglevel']])
    parser['shell'].add_argument(
            '-s', '--shell',
            help=('Select shell to use, defaults to current shell. Used shell'
                  ' should be POSIX compatible shell.'))
    parser['shell'].set_defaults(func=cdist.shell.Shell.commandline)

    for p in parser:
        parser[p].epilog = EPILOG

    return parser


def handle_loglevel(args):
    if args.quiet:
        args.verbose = _verbosity_level_off

    logging.root.setLevel(_verbosity_level[args.verbose])
