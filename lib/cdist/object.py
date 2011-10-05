# -*- coding: utf-8 -*-
#
# 2010-2011 Steven Armstrong (steven-cdist at armstrong.cc)
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

import os
import logging
log = logging.getLogger(__name__)



class Object(object):

    def __init__(self, path, remote_path, object_fq):
        self.path = path
        self.remote_path = remote_path
        self.object_fq = object_fq
        self.type = self.object_fq.split(os.sep)[0]
        self.object_id = self.object_fq.split(os.sep)[1:]
        self.parameter_dir = os.path.join(self.path, "parameter")
        self.remote_object_parameter_dir = os.path.join(self.remote_path, "parameter")
        self.object_code_paths = [
            os.path.join(self.path, "code-local"),
            os.path.join(self.path, "code-remote")]

    @property
    def type_explorer_output_dir(self):
        """Returns and creates dir of the output for a type explorer"""
        if not self.__type_explorer_output_dir:
            dir = os.path.join(self.path, "explorer")
            if not os.path.isdir(dir):
                os.mkdir(dir)
            self.__type_explorer_output_dir = dir
        return self.__type_explorer_output_dir

