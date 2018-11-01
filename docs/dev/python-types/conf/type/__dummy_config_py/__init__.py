import os
import sys
from cdist.core import PythonType, ManifestEntry


class DummyConfig(PythonType):
    def type_manifest(self):
        print('dummy manifest stdout')
        print('dummy manifest stderr\n', file=sys.stderr)
        filepy = ManifestEntry(name='__file_py', stdin='dummy=1\n',
                               parameters={
                                    '/root/dummy1.conf': None,
                                    '--mode': '0640',
                                    '--owner': 'root',
                                    '--group': 'root',
                                    '--source': '-',
                               })
        yield filepy

        self_path = os.path.dirname(os.path.realpath(__file__))
        conf_path = os.path.join(self_path, 'files', 'dummy.conf')
        filepy = ManifestEntry(name='__file_py',
                               parameters={
                                    '/root/dummy2.conf': None,
                                    '--mode': '0600',
                                    '--owner': 'root',
                                    '--group': 'root',
                                    '--source': conf_path,
                               })
        yield filepy
