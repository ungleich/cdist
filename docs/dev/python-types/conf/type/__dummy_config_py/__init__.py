import os
import sys
from cdist.core.pytypes import *


class DummyConfig(PythonType):
    def type_manifest(self):
        print('dummy manifest stdout')
        print('dummy manifest stderr\n', file=sys.stderr)
        yield file_py('/root/dummy1.conf',
                      mode='0640',
                      owner='root',
                      group='root',
                      source='-').feed_stdin('dummy=1\n')

        self_path = os.path.dirname(os.path.realpath(__file__))
        conf_path = os.path.join(self_path, 'files', 'dummy.conf')
        yield file_py('/root/dummy2.conf',
                      mode='0640',
                      owner='root',
                      group='root',
                      source=conf_path)
