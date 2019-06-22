import logging
import os
import io
import sys
import re
from cdist import message, Error
import importlib.util
import inspect
import cdist


__all__ = ["PythonType", "Command", "command"]


class PythonType:
    def __init__(self, env, cdist_object, local, remote, message_prefix=None):
        self.env = env
        self.cdist_object = cdist_object
        self.local = local
        self.remote = remote
        if self.cdist_object:
            self.object_id = cdist_object.object_id
            self.object_name = cdist_object.name
            self.cdist_type = cdist_object.cdist_type
            self.object_path = cdist_object.absolute_path
            self.explorer_path = os.path.join(self.object_path, 'explorer')
            self.type_path = cdist_object.cdist_type.absolute_path
            self.parameters = cdist_object.parameters
            self.stdin_path = os.path.join(self.object_path, 'stdin')
        if self.local:
            self.log = logging.getLogger(
                self.local.target_host[0] + ':' + self.object_name)

        self.message_prefix = message_prefix
        self.message = None

    def get_parameter(self, name):
        return self.parameters.get(name)

    def get_explorer_file(self, name):
        path = os.path.join(self.explorer_path, name)
        return path

    def get_explorer(self, name):
        path = self.get_explorer_file(name)
        with open(path, 'r') as f:
            value = f.read()
            if value:
                value = value.strip()
            return value

    def run_local(self, command, env=None):
        rv = self.local.run(command, env=env, return_output=True)
        if rv:
            rv = rv.rstrip('\n')
        return rv

    def run_remote(self, command, env=None):
        rv = self.remote.run(command, env=env, return_output=True)
        if rv:
            rv = rv.rstrip('\n')
        return rv

    def transfer(self, source, destination):
        self.remote.transfer(source, destination)

    def die(self, msg):
        raise Error("{}: {}".format(self.cdist_object, msg))

    def manifest(self, stdout=None, stderr=None):
        try:
            if self.message_prefix:
                self.message = message.Message(self.message_prefix,
                                               self.local.messages_path)
                self.env.update(self.message.env)
            if stdout is not None:
                stdout_save = sys.stdout
                sys.stdout = stdout
            if stderr is not None:
                stderr_save = sys.stderr
                sys.stderr = stderr
            yield from self.type_manifest()
        finally:
            if self.message:
                self.message.merge_messages()
            if stdout is not None:
                sys.stdout = stdout_save
            if stderr is not None:
                sys.stderr = stderr_save

    def run(self, stdout=None, stderr=None):
        try:
            if self.message_prefix:
                self.message = message.Message(self.message_prefix,
                                               self.local.messages_path)
            if stdout is not None:
                stdout_save = sys.stdout
                sys.stdout = stdout
            if stderr is not None:
                stderr_save = sys.stderr
                sys.stderr = stderr
            return self.type_gencode()
        finally:
            if self.message:
                self.message.merge_messages()
            if stdout is not None:
                sys.stdout = stdout_save
            if stderr is not None:
                sys.stderr = stderr_save

    def send_message(self, msg):
        if self.message:
            with open(self.message.messages_out, 'a') as f:
                print(msg, file=f)

    def receive_message(self, pattern):
        if self.message:
            with open(self.message.messages_in, 'r') as f:
                for line in f:
                    match = re.search(pattern, line)
                    if match:
                        return match
        return None

    def get_args_parser(self):
        pass

    def type_manifest(self):
        pass

    def type_gencode(self):
        pass


class Command:
    def __init__(self, name, *args, **kwargs):
        self.name = name
        self.args = args
        self.kwargs = kwargs
        self.stdin = None

    def feed_stdin(self, value):
        # If file-like object then read its value.
        if value is not None and isinstance(value, io.IOBase):
            value = value.read()

        # Convert to bytes file-like object.
        if value is None:
            self.stdin = None
        elif isinstance(value, str):
            self.stdin = io.BytesIO(value.encode('utf-8'))
        elif isinstance(value, bytes) or isinstance(value, bytearray):
            self.stdin = io.BytesIO(value)
        else:
            raise TypeError("value must be str, bytes, bytearray, file-like "
                            "object or None")
        return self

    def cmd_line(self):
        argv = [self.name, ]
        for param in self.args:
            argv.append(param)
        for key, value in self.kwargs.items():
            argv.append("--{}".format(key))
            argv.append(value)
        return argv


def command(name, *args, **kwargs):
    return Command(name, *args, **kwargs)


def get_pytype_class(cdist_type):
    module_name = cdist_type.name
    file_path = os.path.join(cdist_type.absolute_path, '__init__.py')
    type_class = None
    if os.path.isfile(file_path):
        spec = importlib.util.spec_from_file_location(module_name, file_path)
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        classes = inspect.getmembers(m, inspect.isclass)
        for _, cl in classes:
            if cl != PythonType and issubclass(cl, PythonType):
                if type_class:
                    raise cdist.Error(
                        "Only one python type class is supported, but at least"
                        " two found: {}".format((type_class, cl, )))
                else:
                    type_class = cl
    return type_class
