from distutils.core import setup
import cdist
import os
import re


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
    packages=["cdist", "cdist.core", "cdist.exec", "cdist.util", ],
    package_data={'cdist': package_data},
    scripts=["scripts/cdist"],
    version=cdist.version.VERSION,
    description="A Usable Configuration Management System",
    author="Nico Schottelius",
    author_email="nico-cdist-pypi@schottelius.org",
    url="http://www.nico.schottelius.org/software/cdist/",
    classifiers=[
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
    long_description='''
        cdist is a usable configuration management system.
        It adheres to the KISS principle and is being used in small up to
        enterprise grade environments.
        cdist is an alternative to other configuration management systems like
        cfengine, bcfg2, chef and puppet.
    '''
)
