class Path:
    """Class that handles path related configurations"""

    def __init__(self, home=None):
        if home:
            self.base_dir = home
        else:
            self.base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))

        
        print("Base:" + self.base_dir)
