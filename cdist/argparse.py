import argparse
import cdist
import multiprocessing
import logging
import collections
import functools
import cdist.configuration


# set of beta sub-commands
BETA_COMMANDS = set(('install', 'inventory', ))
# set of beta arguments for sub-commands
BETA_ARGS = {
    'config': set(('jobs', 'tag', 'all_tagged_hosts', 'use_archiving', )),
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


# Generate verbosity level constants:
# VERBOSE_OFF, VERBOSE_ERROR, VERBOSE_WARNING, VERBOSE_INFO, VERBOSE_VERBOSE,
# VERBOSE_DEBUG, VERBOSE_TRACE.
this_globals = globals()
for level in _verbosity_level:
    const = 'VERBOSE_' + logging.getLevelName(_verbosity_level[level])
    this_globals[const] = level


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


def check_lower_bounded_int(value, lower_bound, name):
    try:
        val = int(value)
    except ValueError:
        raise argparse.ArgumentTypeError(
                "{} is invalid int value".format(value))
    if val < lower_bound:
        raise argparse.ArgumentTypeError(
                "{} is invalid {} value".format(val, name))
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
            '-l', '--log-level', metavar='LOGLEVEL',
            type=functools.partial(check_lower_bounded_int, lower_bound=-1,
                                   name="log level"),
            help=('Set the specified verbosity level. '
                  'The levels, in order from the lowest to the highest, are: '
                  'ERROR (-1), WARNING (0), INFO (1), VERBOSE (2), DEBUG (3) '
                  'TRACE (4 or higher). If used along with -v then -v '
                  'increases last set value and -l overwrites last set '
                  'value.'),
            action='store', dest='verbose', required=False)
    parser['loglevel'].add_argument(
            '-q', '--quiet',
            help='Quiet mode: disables logging, including WARNING and ERROR.',
            action='store_true', default=False)
    parser['loglevel'].add_argument(
            '-v', '--verbose',
            help=('Increase the verbosity level. Every instance of -v '
                  'increments the verbosity level by one. Its default value '
                  'is 0 which includes ERROR and WARNING levels. '
                  'The levels, in order from the lowest to the highest, are: '
                  'ERROR (-1), WARNING (0), INFO (1), VERBOSE (2), DEBUG (3) '
                  'TRACE (4 or higher). If used along with -l then -l '
                  'overwrites last set value and -v increases last set '
                  'value.'),
            action='count', default=None)

    parser['beta'] = argparse.ArgumentParser(add_help=False)
    parser['beta'].add_argument(
           '-b', '--beta',
           help=('Enable beta functionality. '),
           action='store_true', dest='beta', default=None)

    # Main subcommand parser
    parser['main'] = argparse.ArgumentParser(
            description='cdist ' + cdist.VERSION)
    parser['main'].add_argument(
            '-V', '--version', help='Show version.', action='version',
            version='%(prog)s ' + cdist.VERSION)
    parser['sub'] = parser['main'].add_subparsers(
            title="Commands", dest="command")

    # Banner
    parser['banner'] = parser['sub'].add_parser(
            'banner', parents=[parser['loglevel']])
    parser['banner'].set_defaults(func=cdist.banner.banner)

    parser['inventory_common'] = argparse.ArgumentParser(add_help=False)
    parser['inventory_common'].add_argument(
           '-I', '--inventory',
           help=('Use specified custom inventory directory. '
                 'Inventory directory is set up by the following rules: '
                 'if cdist configuration resolves this value then specified '
                 'directory is used, '
                 'if HOME env var is set then ~/.cdist/inventory is '
                 'used, otherwise distribution inventory directory is used.'),
           dest="inventory_dir", required=False)

    parser['common'] = argparse.ArgumentParser(add_help=False)
    parser['common'].add_argument(
           '-g', '--config-file',
           help=('Use specified custom configuration file.'),
           dest="config_file", required=False)

    # Config
    parser['config_main'] = argparse.ArgumentParser(add_help=False)
    parser['config_main'].add_argument(
            '-C', '--cache-path-pattern',
            help=('Specify custom cache path pattern. If '
                  'it is not set then default hostdir is used.'),
            dest='cache_path_pattern',
            default=None)
    parser['config_main'].add_argument(
            '-c', '--conf-dir',
            help=('Add configuration directory (can be repeated, '
                  'last one wins).'), action='append')
    parser['config_main'].add_argument(
           '-i', '--initial-manifest',
           help='Path to a cdist manifest or \'-\' to read from stdin.',
           dest='manifest', required=False)
    parser['config_main'].add_argument(
           '-j', '--jobs', nargs='?',
           type=functools.partial(check_lower_bounded_int, lower_bound=1,
                                  name="positive int"),
           help=('Operate in parallel in specified maximum number of jobs. '
                 'Global explorers, object prepare and object run are '
                 'supported. Without argument CPU count is used by default. '
                 'Currently in beta.'),
           action='store', dest='jobs',
           const=multiprocessing.cpu_count())
    parser['config_main'].add_argument(
           '-n', '--dry-run',
           help='Do not execute code.', action='store_true')
    parser['config_main'].add_argument(
           '-o', '--out-dir',
           help='Directory to save cdist output in.', dest="out_path")
    parser['config_main'].add_argument(
           '-R', '--use-archiving', nargs='?',
           choices=('tar', 'tgz', 'tbz2', 'txz',),
           help=('Operate by using archiving with compression where '
                 'appropriate. Supported values are: tar - tar archive, '
                 'tgz - gzip tar archive (the default), '
                 'tbz2 - bzip2 tar archive and txz - lzma tar archive. '
                 'Currently in beta.'),
           action='store', dest='use_archiving',
           const='tgz')

    # remote-copy and remote-exec defaults are environment variables
    # if set; if not then None - these will be futher handled after
    # parsing to determine implementation default
    parser['config_main'].add_argument(
           '-r', '--remote-out-dir',
           help='Directory to save cdist output in on the target host.',
           dest="remote_out_path")
    parser['config_main'].add_argument(
           '--remote-copy',
           help='Command to use for remote copy (should behave like scp).',
           action='store', dest='remote_copy',
           default=None)
    parser['config_main'].add_argument(
           '--remote-exec',
           help=('Command to use for remote execution '
                 '(should behave like ssh).'),
           action='store', dest='remote_exec',
           default=None)

    # Config
    parser['config_args'] = argparse.ArgumentParser(add_help=False)
    parser['config_args'].add_argument(
           '-4', '--force-ipv4',
           help=('Force to use IPv4 addresses only. No influence for custom'
                 ' remote commands.'),
           action='store_const', dest='force_ipv', const=4)
    parser['config_args'].add_argument(
           '-6', '--force-ipv6',
           help=('Force to use IPv6 addresses only. No influence for custom'
                 ' remote commands.'),
           action='store_const', dest='force_ipv', const=6)
    parser['config_args'].add_argument(
             '-A', '--all-tagged',
             help=('Use all hosts present in tags db. Currently in beta.'),
             action="store_true", dest="all_tagged_hosts", default=False)
    parser['config_args'].add_argument(
             '-a', '--all',
             help=('List hosts that have all specified tags, '
                   'if -t/--tag is specified.'),
             action="store_true", dest="has_all_tags", default=False)
    parser['config_args'].add_argument(
            'host', nargs='*', help='Host(s) to operate on.')
    parser['config_args'].add_argument(
            '-f', '--file',
            help=('Read specified file for a list of additional hosts to '
                  'operate on or if \'-\' is given, read stdin (one host per '
                  'line). If no host or host file is specified then, by '
                  'default, read hosts from stdin.'),
            dest='hostfile', required=False)
    parser['config_args'].add_argument(
           '-p', '--parallel', nargs='?', metavar='HOST_MAX',
           type=functools.partial(check_lower_bounded_int, lower_bound=1,
                                  name="positive int"),
           help=('Operate on multiple hosts in parallel for specified maximum '
                 'hosts at a time. Without argument CPU count is used by '
                 'default.'),
           action='store', dest='parallel',
           const=multiprocessing.cpu_count())
    parser['config_args'].add_argument(
           '-S', '--disable-saving-output-streams',
           help='Disable saving output streams.',
           action='store_false', dest='save_output_streams', default=True)
    parser['config_args'].add_argument(
           '-s', '--sequential',
           help='Operate on multiple hosts sequentially (default).',
           action='store_const', dest='parallel', const=0)
    parser['config_args'].add_argument(
             '-t', '--tag',
             help=('Host is specified by tag, not hostname/address; '
                   'list all hosts that contain any of specified tags. '
                   'Currently in beta.'),
             dest='tag', required=False, action="store_true", default=False)
    parser['config'] = parser['sub'].add_parser(
            'config', parents=[parser['loglevel'], parser['beta'],
                               parser['common'],
                               parser['config_main'],
                               parser['inventory_common'],
                               parser['config_args']])
    parser['config'].set_defaults(func=cdist.config.Config.commandline)

    # Install
    parser['install'] = parser['sub'].add_parser('install', add_help=False,
                                                 parents=[parser['config']])
    parser['install'].set_defaults(func=cdist.install.Install.commandline)

    # Inventory
    parser['inventory'] = parser['sub'].add_parser('inventory')
    parser['invsub'] = parser['inventory'].add_subparsers(
            title="Inventory commands", dest="subcommand")

    parser['add-host'] = parser['invsub'].add_parser(
            'add-host', parents=[parser['loglevel'], parser['beta'],
                                 parser['common'],
                                 parser['inventory_common']])
    parser['add-host'].add_argument(
            'host', nargs='*', help='Host(s) to add.')
    parser['add-host'].add_argument(
           '-f', '--file',
           help=('Read additional hosts to add from specified file '
                 'or from stdin if \'-\' (each host on separate line). '
                 'If no host or host file is specified then, by default, '
                 'read from stdin.'),
           dest='hostfile', required=False)

    parser['add-tag'] = parser['invsub'].add_parser(
            'add-tag', parents=[parser['loglevel'], parser['beta'],
                                parser['common'],
                                parser['inventory_common']])
    parser['add-tag'].add_argument(
           'host', nargs='*',
           help='List of host(s) for which tags are added.')
    parser['add-tag'].add_argument(
           '-f', '--file',
           help=('Read additional hosts to add tags from specified file '
                 'or from stdin if \'-\' (each host on separate line). '
                 'If no host or host file is specified then, by default, '
                 'read from stdin. If no tags/tagfile nor hosts/hostfile'
                 ' are specified then tags are read from stdin and are'
                 ' added to all hosts.'),
           dest='hostfile', required=False)
    parser['add-tag'].add_argument(
           '-T', '--tag-file',
           help=('Read additional tags to add from specified file '
                 'or from stdin if \'-\' (each tag on separate line). '
                 'If no tag or tag file is specified then, by default, '
                 'read from stdin. If no tags/tagfile nor hosts/hostfile'
                 ' are specified then tags are read from stdin and are'
                 ' added to all hosts.'),
           dest='tagfile', required=False)
    parser['add-tag'].add_argument(
           '-t', '--taglist',
           help=("Tag list to be added for specified host(s), comma separated"
                 " values."),
           dest="taglist", required=False)

    parser['del-host'] = parser['invsub'].add_parser(
            'del-host', parents=[parser['loglevel'], parser['beta'],
                                 parser['common'],
                                 parser['inventory_common']])
    parser['del-host'].add_argument(
            'host', nargs='*', help='Host(s) to delete.')
    parser['del-host'].add_argument(
            '-a', '--all', help=('Delete all hosts.'),
            dest='all', required=False, action="store_true", default=False)
    parser['del-host'].add_argument(
            '-f', '--file',
            help=('Read additional hosts to delete from specified file '
                  'or from stdin if \'-\' (each host on separate line). '
                  'If no host or host file is specified then, by default, '
                  'read from stdin.'),
            dest='hostfile', required=False)

    parser['del-tag'] = parser['invsub'].add_parser(
            'del-tag', parents=[parser['loglevel'], parser['beta'],
                                parser['common'],
                                parser['inventory_common']])
    parser['del-tag'].add_argument(
            'host', nargs='*',
            help='List of host(s) for which tags are deleted.')
    parser['del-tag'].add_argument(
            '-a', '--all',
            help=('Delete all tags for specified host(s).'),
            dest='all', required=False, action="store_true", default=False)
    parser['del-tag'].add_argument(
            '-f', '--file',
            help=('Read additional hosts to delete tags for from specified '
                  'file or from stdin if \'-\' (each host on separate line). '
                  'If no host or host file is specified then, by default, '
                  'read from stdin. If no tags/tagfile nor hosts/hostfile'
                  ' are specified then tags are read from stdin and are'
                  ' deleted from all hosts.'),
            dest='hostfile', required=False)
    parser['del-tag'].add_argument(
            '-T', '--tag-file',
            help=('Read additional tags from specified file '
                  'or from stdin if \'-\' (each tag on separate line). '
                  'If no tag or tag file is specified then, by default, '
                  'read from stdin. If no tags/tagfile nor'
                  ' hosts/hostfile are specified then tags are read from'
                  ' stdin and are added to all hosts.'),
            dest='tagfile', required=False)
    parser['del-tag'].add_argument(
            '-t', '--taglist',
            help=("Tag list to be deleted for specified host(s), "
                  "comma separated values."),
            dest="taglist", required=False)

    parser['list'] = parser['invsub'].add_parser(
            'list', parents=[parser['loglevel'], parser['beta'],
                             parser['common'],
                             parser['inventory_common']])
    parser['list'].add_argument(
            'host', nargs='*', help='Host(s) to list.')
    parser['list'].add_argument(
            '-a', '--all',
            help=('List hosts that have all specified tags, '
                  'if -t/--tag is specified.'),
            action="store_true", dest="has_all_tags", default=False)
    parser['list'].add_argument(
            '-f', '--file',
            help=('Read additional hosts to list from specified file '
                  'or from stdin if \'-\' (each host on separate line). '
                  'If no host or host file is specified then, by default, '
                  'list all.'), dest='hostfile', required=False)
    parser['list'].add_argument(
            '-H', '--host-only', help=('Suppress tags listing.'),
            action="store_true", dest="list_only_host", default=False)
    parser['list'].add_argument(
            '-t', '--tag',
            help=('Host is specified by tag, not hostname/address; '
                  'list all hosts that contain any of specified tags.'),
            action="store_true", default=False)

    parser['inventory'].set_defaults(
            func=cdist.inventory.Inventory.commandline)

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
    if hasattr(args, 'quiet') and args.quiet:
        args.verbose = _verbosity_level_off

    logging.root.setLevel(_verbosity_level[args.verbose])


def parse_and_configure(argv, singleton=True):
    parser = get_parsers()
    parser_args = parser['main'].parse_args(argv)
    try:
        cfg = cdist.configuration.Configuration(parser_args,
                                                singleton=singleton)
        args = cfg.get_args()
    except ValueError as e:
        raise cdist.Error(str(e))
    # Loglevels are handled globally in here
    handle_loglevel(args)

    log = logging.getLogger("cdist")

    log.verbose("version %s" % cdist.VERSION)
    log.trace('command line args: {}'.format(cfg.command_line_args))
    log.trace('configuration: {}'.format(cfg.get_config()))
    log.trace('configured args: {}'.format(args))

    check_beta(vars(args))

    return parser, cfg
