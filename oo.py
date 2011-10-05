import os
import tempfile

# FIXME: change these to match your environment
os.environ['__cdist_base_dir'] = '/home/sar/vcs/cdist'
# FIXME: testing against the cache, change path
os.environ['__cdist_out_dir'] = '/home/sar/vcs/cdist/cache/sans-asteven-02.ethz.ch/out'


'''
cd /path/to/dir/with/this/file
ipython


In [1]: import oo

In [2]: t = oo.Type('__mkfs')

In [3]: t.
t.base_dir             t.is_install           t.list_type_names      t.name                 t.path                 
t.explorers            t.is_singleton         t.list_types           t.optional_parameters  t.required_parameters  

In [3]: t.path
Out[3]: '/home/sar/vcs/cdist/conf/type/__mkfs'

In [4]: t.required_parameters
Out[4]: ['type']

In [5]: t.optional_parameters
Out[5]: ['device', 'options', 'blocks']

In [6]: t.is
t.is_install    t.is_singleton  

In [6]: t.is_singleton
Out[6]: False

In [7]: o = oo.Object(t, 'dev/sda1')

In [8]: o.
o.base_dir           o.list_object_names  o.list_type_names    o.parameter          o.qualified_name     o.type
o.changed            o.list_objects       o.object_id          o.path               o.requirements       

In [8]: o.pa
o.parameter  o.path       

In [8]: o.path
Out[8]: '/home/sar/vcs/cdist/cache/sans-asteven-02.ethz.ch/out/object/__mkfs/dev/sda1/.cdist'

In [9]: o.changed
Out[9]: False

In [10]: o.changed = True

In [11]: # creates /home/sar/vcs/cdist/cache/sans-asteven-02.ethz.ch/out/object/__mkfs/dev/sda1/.cdist/changed

In [12]: o.changed
Out[12]: True

In [13]: o.changed = False

In [14]: # removes /home/sar/vcs/cdist/cache/sans-asteven-02.ethz.ch/out/object/__mkfs/dev/sda1/.cdist/changed

In [15]:

'''

class Type(object):

    @staticmethod
    def base_dir():
        """Return the absolute path to the top level directory where types
        are defined.

        Requires the environment variable '__cdist_base_dir' to be set.

        """
        return os.path.join(
            os.environ['__cdist_base_dir'],
            'conf',
            'type'
        )

    @classmethod
    def list_types(cls):
        """Return a list of type instances"""
        for type_name in cls.list_type_names():
            yield cls(type_name)

    @classmethod
    def list_type_names(cls):
        """Return a list of type names"""
        return os.listdir(cls.base_dir())


    def __init__(self, name):
        self.name = name
        self.__explorers = None
        self.__required_parameters = None
        self.__optional_parameters = None

    def __repr__(self):
        return '<Type name=%s>' % self.name

    @property
    def path(self):
        return os.path.join(
            self.base_dir(),
            self.name
        ) 

    @property
    def is_singleton(self):
        """Check whether a type is a singleton."""
        return os.path.isfile(os.path.join(self.path, "singleton"))

    @property
    def is_install(self):
        """Check whether a type is used for installation (if not: for configuration)"""
        return os.path.isfile(os.path.join(self.path, "install"))

    @property
    def explorers(self):
        """Return a list of available explorers"""
        if not self.__explorers:
            try:
                self.__explorers = os.listdir(os.path.join(self.path, "explorer"))
            except EnvironmentError as e:
                # error ignored
                self.__explorers = []
        return self.__explorers

    @property
    def required_parameters(self):
        """Return a list of required parameters"""
        if not self.__required_parameters:
            parameters = []
            try:
                with open(os.path.join(self.path, "parameter", "required")) as fd:
                    for line in fd:
                        parameters.append(line.strip())
            except EnvironmentError as e:
                # error ignored
                pass
            finally:
                self.__required_parameters = parameters
        return self.__required_parameters

    @property
    def optional_parameters(self):
        """Return a list of optional parameters"""
        if not self.__optional_parameters:
            parameters = []
            try:
                with open(os.path.join(self.path, "parameter", "optional")) as fd:
                    for line in fd:
                        parameters.append(line.strip())
            except EnvironmentError as e:
                # error ignored
                pass
            finally:
                self.__optional_parameters = parameters
        return self.__optional_parameters


class Object(object):

    @staticmethod
    def base_dir():
        """Return the absolute path to the top level directory where objects
        are defined.

        Requires the environment variable '__cdist_out_dir' to be set.

        """
        base_dir = os.path.join(
            os.environ['__cdist_out_dir'],
            'object'
        )
        # FIXME: should directory be created elsewhere?
        if not os.path.isdir(base_dir):
            os.mkdir(base_dir)
        return base_dir

    @classmethod
    def list_objects(cls):
        """Return a list of object instances"""
        for object_name in cls.list_object_names():
            type_name = object_name.split(os.sep)[0]
            object_id = os.sep.join(object_name.split(os.sep)[1:])
            yield cls(Type(type_name), object_id=object_id)

    @classmethod
    def list_type_names(cls):
        """Return a list of type names"""
        return os.listdir(cls.base_dir())

    @classmethod
    def list_object_names(cls):
        """Return a list of object names"""
        for path, dirs, files in os.walk(cls.base_dir()):
            # FIXME: use constant instead of string
            if '.cdist' in dirs:
                yield os.path.relpath(path, cls.base_dir())

    def __init__(self, type, object_id=None, parameter=None, requirements=None):
        self.type = type # instance of Type
        self.object_id = object_id
        self.qualified_name = os.path.join(self.type.name, self.object_id)
        self.parameter = parameter or {}
        self.requirements = requirements or []
        
    def __repr__(self):
        return '<Object %s>' % self.qualified_name

    @property
    def path(self):
        return os.path.join(
            self.base_dir(),
            self.qualified_name,
            '.cdist'
        )

    @property
    def changed(self):
        """Check whether the object has been changed."""
        return os.path.isfile(os.path.join(self.path, "changed"))

    @changed.setter
    def changed(self, value):
        """Change the objects changed status."""
        path = os.path.join(self.path, "changed")
        if value:
            open(path, "w").close()
        else:
            try:
                os.remove(path)
            except EnvironmentError:
                # ignore
                pass

    # FIXME: implement other properties/methods
