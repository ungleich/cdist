#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 2013 Steven Armstrong (steven-cdist at armstrong.cc)
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

import cdist.config
import cdist.core


class Install(cdist.config.Config):
    def object_list(self):
        """Short name for object list retrieval.
        In install mode, we only care about install objects.
        """
        for cdist_object in cdist.core.CdistObject.list_objects(
                self.local.object_path, self.local.type_path,
                self.local.object_marker_name):
            if cdist_object.cdist_type.is_install:
                yield cdist_object
            else:
                self.log.debug("Running in install mode, ignoring non install"
                               "object: {0}".format(cdist_object))
