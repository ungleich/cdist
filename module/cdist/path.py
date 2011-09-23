class Path:
    """Class that handles path related configurations"""

    def __init__(self, target_host, base_dir=None):
        # Base and Temp Base 
        if home:
            self.base_dir = base_dir
        else:
            self.base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))

        self.temp_dir = tempfile.mkdtemp()

        self.conf_dir               = os.path.join(self.base_dir, "conf")
        self.cache_base_dir         = os.path.join(self.base_dir, "cache")
        self.cache_dir              = os.path.join(self.cache_base_dir, target_host)
        self.global_explorer_dir    = os.path.join(self.conf_dir, "explorer")
        self.lib_dir                = os.path.join(self.base_dir, "lib")
        self.manifest_dir           = os.path.join(self.conf_dir, "manifest")
        self.type_base_dir          = os.path.join(self.conf_dir, "type")

        self.out_dir = os.path.join(self.temp_dir, "out")
        os.mkdir(self.out_dir)

        self.global_explorer_out_dir = os.path.join(self.out_dir, "explorer")
        os.mkdir(self.global_explorer_out_dir)

        self.object_base_dir = os.path.join(self.out_dir, "object")

        # Setup binary directory + contents
        self.bin_dir = os.path.join(self.out_dir, "bin")
        os.mkdir(self.bin_dir)
        self.link_type_to_emulator()

        # List of type explorers transferred
        self.type_explorers_transferred = {}

        # objects
        self.objects_prepared = []

        self.remote_user = remote_user

        # Mostly static, but can be overwritten on user demand
        if initial_manifest:
            self.initial_manifest = initial_manifest
        else:
            self.initial_manifest = os.path.join(self.manifest_dir, "init")

    def cleanup(self):
        # Do not use in __del__:
        # http://docs.python.org/reference/datamodel.html#customization
        # "other globals referenced by the __del__() method may already have been deleted 
        # or in the process of being torn down (e.g. the import machinery shutting down)"
        #
        log.debug("Saving" + self.temp_dir + "to " + self.cache_dir)
        # Remove previous cache
        if os.path.exists(self.cache_dir):
            shutil.rmtree(self.cache_dir)
        shutil.move(self.temp_dir, self.cache_dir)

