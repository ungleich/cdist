from distutils.core import setup

import cdist

setup(
    name = "cdist",
    packages = ["cdist", "cdist.core", "cdist.exec", "cdist.util" ],
    scripts = ["cdist.py"],
    version = cdist.version.VERSION,
    description = "A Usable Configuration Management System",
    author = "Nico Schottelius",
    author_email = "nico-cdist-pypi@schottelius.org",
    url = "http://www.nico.schottelius.org/software/cdist/",
    classifiers = [
        "Development Status :: 6 - Mature",
        "Environment :: Console",
        "Intended Audience :: System Administrators",
        "License :: OSI Approved :: GNU General Public License v3 or later (GPLv3+)",
        "Operating System :: MacOS :: MacOS X",
        "Operating System :: POSIX",
        "Operating System :: POSIX :: BSD",
        "Operating System :: POSIX :: Linux",
        "Operating System :: Unix",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3",
        "Topic :: System :: Boot",
        "Topic :: System :: Installation/Setup",
        "Topic :: System :: Operating System",
        "Topic :: System :: Software Distribution",
        "Topic :: Utilities"
    ],
    long_description = '''
        cdist is a usable configuration management system.
        It adheres to the KISS principle and is being used in small up to enterprise grade environments.
        cdist is an alternative to other configuration management systems like 
        cfengine, bcfg2, chef and puppet.
    '''
)
