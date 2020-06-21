# -*- coding: utf-8 -*-
#
# 2010-2013 Nico Schottelius (nico-cdist at schottelius.org)
# 2019-2020 Steven Armstrong
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

import datetime
import logging
import logging.handlers
import sys
import os
import asyncio
import contextlib
import pickle
import struct
import threading


# Define additional cdist logging levels.
logging.OFF = logging.CRITICAL + 10  # disable logging
logging.addLevelName(logging.OFF, 'OFF')

logging.VERBOSE = logging.INFO - 5
logging.addLevelName(logging.VERBOSE, 'VERBOSE')


def _verbose(msg, *args, **kwargs):
    logging.log(logging.VERBOSE, msg, *args, **kwargs)


logging.verbose = _verbose

logging.TRACE = logging.DEBUG - 5
logging.addLevelName(logging.TRACE, 'TRACE')


def _trace(msg, *args, **kwargs):
    logging.log(logging.TRACE, msg, *args, **kwargs)


logging.trace = _trace


class CdistFormatter(logging.Formatter):
    USE_COLORS = False
    RESET = '\033[0m'
    COLOR_MAP = {
        'ERROR': '\033[0;31m',
        'WARNING': '\033[0;33m',
        'INFO': '\033[0;94m',
        'VERBOSE': '\033[0;34m',
        'DEBUG': '\033[0;90m',
        'TRACE': '\033[0;37m',
    }

    def __init__(self, fmt):
        super().__init__(fmt=fmt)

    def format(self, record):
        msg = super().format(record)
        if self.USE_COLORS:
            color = self.COLOR_MAP.get(record.levelname)
            if color:
                msg = color + msg + self.RESET
        return msg


class DefaultLog(logging.Logger):
    FORMAT = '%(levelname)s: %(name)s: %(message)s'

    class StdoutFilter(logging.Filter):
        def filter(self, rec):
            return rec.levelno != logging.ERROR

    class StderrFilter(logging.Filter):
        def filter(self, rec):
            return rec.levelno == logging.ERROR

    def __init__(self, name):
        super().__init__(name)
        self.propagate = False

        if '__cdist_log_server_socket' in os.environ:
            log_server_socket = os.environ['__cdist_log_server_socket']
            socket_handler = logging.handlers.SocketHandler(log_server_socket,
                                                            None)
            self.addHandler(socket_handler)
        else:
            formatter = CdistFormatter(self.FORMAT)

            stdout_handler = logging.StreamHandler(sys.stdout)
            stdout_handler.addFilter(self.StdoutFilter())
            stdout_handler.setLevel(logging.TRACE)
            stdout_handler.setFormatter(formatter)

            stderr_handler = logging.StreamHandler(sys.stderr)
            stderr_handler.addFilter(self.StderrFilter())
            stderr_handler.setLevel(logging.ERROR)
            stderr_handler.setFormatter(formatter)

            self.addHandler(stdout_handler)
            self.addHandler(stderr_handler)

    def verbose(self, msg, *args, **kwargs):
        self.log(logging.VERBOSE, msg, *args, **kwargs)

    def trace(self, msg, *args, **kwargs):
        self.log(logging.TRACE, msg, *args, **kwargs)


class TimestampingLog(DefaultLog):

    def filter(self, record):
        """Add timestamp to messages"""

        super().filter(record)
        now = datetime.datetime.now()
        timestamp = now.strftime("%Y%m%d%H%M%S.%f")
        record.msg = "[" + timestamp + "] " + str(record.msg)

        return True


class ParallelLog(DefaultLog):
    FORMAT = '%(levelname)s: [%(process)d]: %(name)s: %(message)s'


class TimestampingParallelLog(TimestampingLog, ParallelLog):
    pass


def setupDefaultLogging():
    del logging.getLogger().handlers[:]
    logging.setLoggerClass(DefaultLog)


def setupTimestampingLogging():
    del logging.getLogger().handlers[:]
    logging.setLoggerClass(TimestampingLog)


def setupTimestampingParallelLogging():
    del logging.getLogger().handlers[:]
    logging.setLoggerClass(TimestampingParallelLog)


def setupParallelLogging():
    del logging.getLogger().handlers[:]
    logging.setLoggerClass(ParallelLog)


async def handle_log_client(reader, writer):
    while True:
        chunk = await reader.read(4)
        if len(chunk) < 4:
            return

        data_size = struct.unpack('>L', chunk)[0]
        data = await reader.read(data_size)

        obj = pickle.loads(data)
        record = logging.makeLogRecord(obj)
        logger = logging.getLogger(record.name)
        logger.handle(record)


def run_log_server(server_address):
    # Get a new loop inside the current thread to run the log server.
    loop = asyncio.new_event_loop()
    loop.create_task(asyncio.start_unix_server(handle_log_client,
                                               server_address))
    loop.run_forever()


def setupLogServer(socket_dir, log=logging.getLogger(__name__)):
    """Run a asyncio based unix socket log server in a background thread.
    """
    log_server_socket = os.path.join(socket_dir, 'log-server')
    log.debug('Starting logging server on: %s', log_server_socket)
    os.environ['__cdist_log_server_socket_export'] = log_server_socket
    with contextlib.suppress(FileNotFoundError):
        os.remove(log_server_socket)
    t = threading.Thread(target=run_log_server, args=(log_server_socket,))
    # Deamonizing the thread means we don't have to care about stoping it.
    # It will die together with the main process.
    t.daemon = True
    t.start()


setupDefaultLogging()
