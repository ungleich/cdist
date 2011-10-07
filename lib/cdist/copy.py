    # FIXME: To Copy
    def transfer_dir(self, source, destination):
        """Transfer directory and previously delete the remote destination"""
        self.remove_remote_dir(destination)
        cdist.exec.run_or_fail(os.environ['__remote_copy'].split() +
            ["-r", source, self.target_host + ":" + destination])

    # FIXME: To Copy
    def transfer_file(self, source, destination):
        """Transfer file"""
        cdist.exec.run_or_fail(os.environ['__remote_copy'].split() +
            [source, self.target_host + ":" + destination])

