#!/usr/bin/env python
# encoding: utf-8

# this file is unused in current build system

from distutils.core import setup


setup(name='cdist',
    version='2.0.11',
    description='Usable configuration management system',
    author='Nico Schottelius',
    author_email='nico-cdist at schottelius.org',
    url='http://www.nico.schottelius.org/software/cdist/',
    license="GPL3",
    packages=['cdist', 'cdist.exec', 'cdist.core', 'cdist.util' ],
    package_dir={
	'cdist': 'lib/cdist',
	'cdist.exec': 'lib/cdist/exec',
	'cdist.core': 'lib/cdist/core',
	'cdist.util': 'lib/cdist/util',
	},
    )
