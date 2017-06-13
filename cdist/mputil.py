# -*- coding: utf-8 -*-
#
# 2016 Darko Poljak (darko.poljak at gmail.com)
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


import multiprocessing
import itertools


def mp_pool_run(func, args=None, kwds=None, jobs=multiprocessing.cpu_count()):
    """ Run func using multiprocessing.Pool with jobs jobs and supplied
        iterable of args and kwds with one entry for each parallel func
        instance.
        Return list of results.
    """
    if args and kwds:
        fargs = zip(args, kwds)
    elif args:
        fargs = zip(args, itertools.repeat({}))
    elif kwds:
        fargs = zip(itertools.repeat(()), kwds)
    else:
        return [func(), ]

    with multiprocessing.Pool(jobs) as pool:
        results = [
            pool.apply_async(func, a, k)
            for a, k in fargs
        ]
        retval = [r.get() for r in results]
    return retval
