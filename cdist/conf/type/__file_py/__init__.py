import os
import re
import sys
from cdist.core.pytypes import *


class FileType(PythonType):
    def get_attribute(self, stat_file, attribute, value_should):
        if os.path.exists(stat_file):
            if re.match('[0-9]', value_should):
                index = 1
            else:
                index = 2
            with open(stat_file, 'r') as f:
                for line in f:
                    if re.match(attribute + ":", line):
                        fields = line.split()
                        return fields[index]
            return None

    def set_attribute(self, attribute, value_should, destination):
        cmd = {
            'group': 'chgrp',
            'owner': 'chown',
            'mode': 'chmod',
        }
        self.send_message("{} '{}'".format(cmd[attribute], value_should))
        return "{} '{}' '{}'".format(cmd[attribute], value_should, destination)

    def type_manifest(self):
        yield from ()

    def type_gencode(self):
        typeis = self.get_explorer('type')
        state_should = self.get_parameter('state')

        if state_should == 'exists' and typeis == 'file':
            return

        source = self.get_parameter('source')
        if source == '-':
            source = self.stdin_path
        destination = '/' + self.object_id
        if state_should == 'pre-exists':
            if source is not None:
                self.die('--source cannot be used with --state pre-exists')
            if typeis == 'file':
                return None
            else:
                self.die('File {} does not exist'.format(destination))

        create_file = False
        upload_file = False
        set_attributes = False
        code = []
        if state_should == 'present' or state_should == 'exists':
            if source is None:
                remote_stat = self.get_explorer('stat')
                if not remote_stat:
                    create_file = True
            else:
                if os.path.exists(source):
                    if typeis == 'file':
                        local_cksum = self.run_local(['cksum', source, ])
                        local_cksum = local_cksum.split()[0]
                        remote_cksum = self.get_explorer('cksum')
                        remote_cksum = remote_cksum.split()[0]
                        upload_file = local_cksum != remote_cksum
                    else:
                        upload_file = True
                else:
                    self.die('Source {} does not exist'.format(source))
            if create_file or upload_file:
                set_attributes = True
                tempfile_template = '{}.cdist.XXXXXXXXXX'.format(destination)
                destination_upload = self.run_remote(
                    ["mktemp", tempfile_template, ])
                if upload_file:
                    self.transfer(source, destination_upload)
                code.append('rm -rf {}'.format(destination))
                code.append('mv {} {}'.format(destination_upload, destination))

        if state_should in ('present', 'exists', 'pre-exists', ):
            for attribute in ('group', 'owner', 'mode', ):
                if attribute in self.parameters:
                    value_should = self.get_parameter(attribute)
                    if attribute == 'mode':
                        value_should = re.sub('^0', '', value_should)
                    stat_file = self.get_explorer_file('stat')
                    value_is = self.get_attribute(stat_file, attribute,
                                                  value_should)
                    if set_attributes or value_should != value_is:
                        code.append(self.set_attribute(attribute,
                                                       value_should,
                                                       destination))
        elif state_should == 'absent':
            if typeis == 'file':
                code.append('rm -f {}'.format(destination))
                self.send_message('remove')
        else:
            self.die('Unknown state {}'.format(state_should))

        return "\n".join(code)
