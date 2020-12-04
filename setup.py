from distutils.core import setup
from distutils.errors import DistutilsError
import os
import re
import subprocess


# We have it only if it is a git cloned repo.
build_helper = os.path.join('bin', 'cdist-build-helper')
# Version file path.
version_file = os.path.join('cdist', 'version.py')
# If we have build-helper we could be a git repo.
if os.path.exists(build_helper):
    # Try to generate version.py.
    rv = subprocess.run([build_helper, 'version', ])
    if rv.returncode != 0:
        raise DistutilsError("Failed to generate {}".format(version_file))
else:
    # Otherwise, version.py should be present.
    if not os.path.exists(version_file):
        raise DistutilsError("Missing version file {}".format(version_file))


import cdist  # noqa


def data_finder(data_dir):
    entries = []
    for name in os.listdir(data_dir):

        # Skip .gitignore files
        if name == ".gitignore":
            continue

        # Skip vim swp files
        swpfile = re.search(r'^\..*\.swp$', name)
        if swpfile:
            continue

        entry = os.path.join(data_dir, name)
        if os.path.isdir(entry):
            entries.extend(data_finder(entry))
        else:
            entries.append(entry)

    return entries


cur = os.getcwd()
os.chdir("cdist")
package_data = data_finder("conf")
os.chdir(cur)


setup(
    name="cdist",
    packages=["cdist", "cdist.core", "cdist.exec", "cdist.scan", "cdist.util"],
    package_data={'cdist': package_data},
    scripts=["bin/cdist", "bin/cdist-dump", "bin/cdist-new-type"],
    version=cdist.version.VERSION,
    description="A Usable Configuration Management System",
    author="cdist contributors",
    url="https://cdi.st",
    classifiers=[
        "Development Status :: 6 - Mature",
        "Environment :: Console",
        "Intended Audience :: System Administrators",
        "License :: OSI Approved :: GNU General Public License v3 or later (GPLv3+)",  # noqa
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
    long_description='''
        cdist is a usable configuration management system.
        It adheres to the KISS principle and is being used in small up to
        enterprise grade environments.
        cdist is an alternative to other configuration management systems like
        cfengine, bcfg2, chef and puppet.
    '''
)
