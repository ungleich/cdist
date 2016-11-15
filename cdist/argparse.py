import argparse
import cdist
import multiprocessing
import os
import logging


# list of beta sub-commands
BETA_COMMANDS = ['install', 'inventory', 'preos', 'trigger', ]
# list of beta arguments for sub-commands
BETA_ARGS = {
    'config': ['jobs', 'tag', 'all_tagged_hosts', ],
}
EPILOG = "Get cdist at http://www.nico.schottelius.org/software/cdist/"
# Parser others can reuse
parser = None


def add_beta_command(cmd):
    if cmd not in BETA_COMMANDS:
        BETA_COMMANDS.append(cmd)


def add_beta_arg(cmd, arg):
    if cmd in BETA_ARGS:
        if arg not in BETA_ARGS[cmd]:
            BETA_ARGS[cmd].append(arg)
    else:
        BETA_ARGS[cmd] = [arg, ]


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
    except ValueError as e:
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
            '-d', '--debug', help='Set log level to debug',
            action='store_true', default=False)
    parser['loglevel'].add_argument(
            '-v', '--verbose', help='Set log level to info, be more verbose',
            action='store_true', default=False)

    parser['beta'] = argparse.ArgumentParser(add_help=False)
    parser['beta'].add_argument(
           '-b', '--beta',
           help=('Enable beta functionalities.'),
           action='store_true', dest='beta', default=False)

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

    parser['inventory_common'] = argparse.ArgumentParser(add_help=False)
    parser['inventory_common'].add_argument(
           '-I', '--inventory',
           help=('Use specified custom inventory directory. '
                 'Inventory directory is set up by the following rules: '
                 'if this argument is set then specified directory is used, '
                 'if CDIST_INVENTORY_DIR env var is set then its value is '
                 'used, if HOME env var is set then ~/.cdist/inventory is '
                 'used, otherwise distribution inventory directory is used.'),
           dest="inventory_dir", required=False)

    # Config
    parser['config_main'] = argparse.ArgumentParser(add_help=False)
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
           help=('Specify the maximum number of parallel jobs, currently '
                 'only global explorers are supported'),
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
             '-A', '--all-tagged',
             help=('use all hosts present in tags db'),
             action="store_true", dest="all_tagged_hosts", default=False)
    parser['config_args'].add_argument(
             '-a', '--all',
             help=('list hosts that have all specified tags, '
                   'if -t/--tag is specified'),
             action="store_true", dest="has_all_tags", default=False)
    parser['config_args'].add_argument(
            'host', nargs='*', help='host(s) to operate on')
    parser['config_args'].add_argument(
            '-f', '--file',
            help=('Read additional hosts to operate on from specified file '
                  'or from stdin if \'-\' (each host on separate line). '
                  'If no host or host file is specified then, by default, '
                  'read hosts from stdin.'),
            dest='hostfile', required=False)
    parser['config_args'].add_argument(
           '-p', '--parallel',
           help='operate on multiple hosts in parallel',
           action='store_true', dest='parallel')
    parser['config_args'].add_argument(
           '-s', '--sequential',
           help='operate on multiple hosts sequentially (default)',
           action='store_false', dest='parallel')
    parser['config_args'].add_argument(
             '-t', '--tag',
             help=('host is specified by tag, not hostname/address; '
                   'list all hosts that contain any of specified tags'),
             dest='tag', required=False, action="store_true", default=False)
    parser['config'] = parser['sub'].add_parser(
            'config', parents=[parser['loglevel'], parser['beta'],
                               parser['config_main'],
                               parser['inventory_common'],
                               parser['config_args']])
    parser['config'].set_defaults(func=cdist.config.Config.commandline)

    # Install
    parser['install'] = parser['sub'].add_parser('install', add_help=False,
                                                 parents=[parser['config']])
    parser['install'].set_defaults(func=cdist.install.Install.commandline)

    # Inventory
    parser['inventory'] = parser['sub'].add_parser(
           'inventory', parents=[parser['loglevel'], parser['beta'],
                                 parser['inventory_common']])
    parser['invsub'] = parser['inventory'].add_subparsers(
            title="Inventory commands", dest="subcommand")

    parser['add-host'] = parser['invsub'].add_parser(
            'add-host', parents=[parser['loglevel'], parser['beta'],
                                 parser['inventory_common']])
    parser['add-host'].add_argument(
            'host', nargs='*', help='host(s) to add')
    parser['add-host'].add_argument(
           '-f', '--file',
           help=('Read additional hosts to add from specified file '
                 'or from stdin if \'-\' (each host on separate line). '
                 'If no host or host file is specified then, by default, '
                 'read from stdin.'),
           dest='hostfile', required=False)

    parser['add-tag'] = parser['invsub'].add_parser(
            'add-tag', parents=[parser['loglevel'], parser['beta'],
                                parser['inventory_common']])
    parser['add-tag'].add_argument(
           'host', nargs='*',
           help='list of host(s) for which tags are added')
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
                 " values"),
           dest="taglist", required=False)

    parser['del-host'] = parser['invsub'].add_parser(
            'del-host', parents=[parser['loglevel'], parser['beta'],
                                 parser['inventory_common']])
    parser['del-host'].add_argument(
            'host', nargs='*', help='host(s) to delete')
    parser['del-host'].add_argument(
            '-a', '--all', help=('Delete all hosts'),
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
                                parser['inventory_common']])
    parser['del-tag'].add_argument(
            'host', nargs='*',
            help='list of host(s) for which tags are deleted')
    parser['del-tag'].add_argument(
            '-a', '--all',
            help=('Delete all tags for specified host(s)'),
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
                  "comma separated values"),
            dest="taglist", required=False)

    parser['list'] = parser['invsub'].add_parser(
            'list', parents=[parser['loglevel'], parser['beta'],
                             parser['inventory_common']])
    parser['list'].add_argument(
            'host', nargs='*', help='host(s) to list')
    parser['list'].add_argument(
            '-a', '--all',
            help=('list hosts that have all specified tags, '
                  'if -t/--tag is specified'),
            action="store_true", dest="has_all_tags", default=False)
    parser['list'].add_argument(
            '-f', '--file',
            help=('Read additional hosts to list from specified file '
                  'or from stdin if \'-\' (each host on separate line). '
                  'If no host or host file is specified then, by default, '
                  'list all.'), dest='hostfile', required=False)
    parser['list'].add_argument(
            '-H', '--host-only', help=('Suppress tags listing'),
            action="store_true", dest="list_only_host", default=False)
    parser['list'].add_argument(
            '-t', '--tag',
            help=('host is specified by tag, not hostname/address; '
                  'list all hosts that contain any of specified tags'),
            action="store_true", default=False)

    parser['inventory'].set_defaults(
            func=cdist.inventory.Inventory.commandline)

    # PreOs
    parser['preos'] = parser['sub'].add_parser('preos', add_help=False)

    # Shell
    parser['shell'] = parser['sub'].add_parser(
            'shell', parents=[parser['loglevel']])
    parser['shell'].add_argument(
            '-s', '--shell',
            help=('Select shell to use, defaults to current shell. Used shell'
                  ' should be POSIX compatible shell.'))
    parser['shell'].set_defaults(func=cdist.shell.Shell.commandline)

    # Trigger
    parser['trigger'] = parser['sub'].add_parser(
            'trigger', parents=[parser['loglevel'],
                                parser['beta'],
                                parser['config_main']])
    parser['trigger'].add_argument(
            '-6', '--ipv6', default=False,
            help=('Listen to both IPv4 and IPv6 (instead of only IPv4)'),
            action='store_true')
    parser['trigger'].add_argument(
            '-H', '--http-port', action='store', default=3000, required=False,
            help=('Create trigger listener via http on specified port'))
    parser['trigger'].set_defaults(func=cdist.trigger.Trigger.commandline)

    # Install
    parser['install'] = parser['sub'].add_parser('install', add_help=False,
                                                 parents=[parser['config']])
    parser['install'].set_defaults(func=cdist.install.Install.commandline)

    for p in parser:
        parser[p].epilog = EPILOG

    return parser


def handle_loglevel(args):
    if args.verbose:
        logging.root.setLevel(logging.INFO)
    if args.debug:
        logging.root.setLevel(logging.DEBUG)
