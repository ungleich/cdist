    # FIXME: Explorer or stays
    def global_explorer_output_path(self, explorer):
        """Returns path of the output for a global explorer"""
        return os.path.join(self.global_explorer_out_dir, explorer)

    # FIXME Stays here / Explorer?
    def remote_global_explorer_path(self, explorer):
        """Returns path to the remote explorer"""
        return os.path.join(REMOTE_GLOBAL_EXPLORER_DIR, explorer)

    # FIXME: stays here
    def list_global_explorers(self):
        """Return list of available explorers"""
        return os.listdir(self.global_explorer_dir)

