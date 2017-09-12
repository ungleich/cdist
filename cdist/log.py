#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2010-2013 Nico Schottelius (nico-cdist at schottelius.org)
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

import logging
import sys


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


class DefaultLog(logging.Logger):

    FORMAT = '%(levelname)s: %(message)s'

    class StdoutFilter(logging.Filter):
        def filter(self, rec):
            return rec.levelno != logging.ERROR

    class StderrFilter(logging.Filter):
        def filter(self, rec):
            return rec.levelno == logging.ERROR

    def __init__(self, name):
        super().__init__(name)

        formatter = logging.Formatter(self.FORMAT)

        self.addFilter(self)

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

    def filter(self, record):
        """Prefix messages with logger name"""

        record.msg = self.name + ": " + str(record.msg)

        return True

    def verbose(self, msg, *args, **kwargs):
        self.log(logging.VERBOSE, msg, *args, **kwargs)

    def trace(self, msg, *args, **kwargs):
        self.log(logging.TRACE, msg, *args, **kwargs)


class ParallelLog(DefaultLog):
    FORMAT = '%(levelname)s: [%(process)d]: %(message)s'


def setupDefaultLogging():
    del logging.getLogger().handlers[:]
    logging.setLoggerClass(DefaultLog)


def setupParallelLogging():
    del logging.getLogger().handlers[:]
    logging.setLoggerClass(ParallelLog)


setupDefaultLogging()
