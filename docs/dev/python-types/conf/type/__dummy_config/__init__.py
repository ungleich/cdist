import os
import sys
from cdist.core import PythonType, ManifestEntry


class DummyConfig(PythonType):
    def type_manifest(self):
        print('dummy py manifest stdout')
        print('dummy py manifest stderr', file=sys.stderr)
        filepy = ManifestEntry(name='__file_py', stdin='dummy=py\n',
                               parameters={
                                    '/root/dummypy.conf': None,
                                    '--mode': '0640',
                                    '--owner': 'root',
                                    '--group': 'root',
                                    '--source': '-',
                               })
        self.log.info('Created manifest entry %s', filepy)
        yield filepy

        self_path = os.path.dirname(os.path.realpath(__file__))
        conf_path = os.path.join(self_path, 'files', 'dummypy.conf')
        filepy = ManifestEntry(name='__file_py',
                               parameters={
                                    '/root/dummypy2.conf': None,
                                    '--mode': '0640',
                                    '--owner': 'root',
                                    '--group': 'root',
                                    '--source': conf_path,
                               })
        yield filepy

        self_path = os.path.dirname(os.path.realpath(__file__))
        conf_path = os.path.join(self_path, 'files', 'dummysh.conf')
        with open(conf_path, 'r') as f:
            filepy = ManifestEntry(name='__file', stdin=f,
                                   parameters={
                                        '/root/dummysh.conf': None,
                                        '--mode': '0600',
                                        '--owner': 'root',
                                        '--group': 'root',
                                        '--source': '-',
                                   })
            yield filepy

    def type_gencode(self):
        print('__dummy_config test stdout')
        print('__dummy_config test stderr', file=sys.stderr)
        pattern = "__file_py/root/dummypy2.conf:chgrp 'root'"
        match = self.receive_message(pattern)
        print('Received message:', match.string if match else None)
        return None
