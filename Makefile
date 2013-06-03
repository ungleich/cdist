#
# 2013 Nico Schottelius (nico-cdist at schottelius.org)
#
# This file is part of cdist.
#
# cdist is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# cdist is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with cdist. If not, see <http://www.gnu.org/licenses/>.
#
#

MANDIR=docs/man
MAN1DSTDIR=$(MANDIR)/man1
MAN7DSTDIR=$(MANDIR)/man7
MANREF=$(MAN7DSTDIR)/cdist-reference.text
MANREFSH=$(MANDIR)/cdist-reference.text.sh

CHECKS=check-version check-date

DIST=dist-tag dist-branch-merge 

RELEASE=release-web release-man release-pypi release-archlinux-makepkg
RELEASE+=release-blog release-ml
RELEASE+=release-freecode release-archlinux-aur-upload

helper=./build-helper
version=`git describe`
versionchangelog=`$(helper) changelog-version`
versionfile=cdist/version.py

archlinuxtar=cdist-${versionchangelog}-1.src.tar.gz

$(versionfile):
	echo $(version) > $@


$(DIST): dist-check
$(RELEASE): $(DIST) $(CHECKS)

man: $(MANREF) mantype manbuild

$(MANREF): $(MANREFSH)
	$(MANREFSH)

################################################################################
# generic code
#


################################################################################
# dist code
#
dist-check: man

dist: $(DIST)
	echo "Run \"make release\" to release to the public"

dist-pypi: man version
	python3 setup.py sdist upload

$(archlinuxtar): PKGBUILD dist-pypi
	makepkg -c --source

################################################################################
# release code
#
release: pub $(RELEASE)
	echo "Don't forget...: linkedin"


release-archlinux: $(archlinuxtar)
	burp -c system $^
	
release-blog: blog
release-ml: release-blog
release-pub: man

release-web: web-doc

PKGBUILD: PKGBUILD.in
	./PKGBUILD.in

################################################################################
# generic call
%:
	$(helper) $@
