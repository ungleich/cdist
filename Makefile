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

helper=./bin/build-helper

DOCS_SRC_DIR=docs/src
SPEECHDIR=docs/speeches
TYPEDIR=cdist/conf/type

WEBSRCDIR=docs/web

WEBDIR=$$HOME/vcs/www.nico.schottelius.org
WEBBLOG=$(WEBDIR)/blog
WEBBASE=$(WEBDIR)/software/cdist
WEBPAGE=$(WEBBASE).mdwn

CHANGELOG_VERSION=$(shell $(helper) changelog-version)
CHANGELOG_FILE=docs/changelog

PYTHON_VERSION=cdist/version.py

SPHINXM=make -C $(DOCS_SRC_DIR) man
SPHINXH=make -C $(DOCS_SRC_DIR) html
SPHINXC=make -C $(DOCS_SRC_DIR) clean
################################################################################
# Manpages
#
MAN1DSTDIR=$(DOCS_SRC_DIR)/man1
MAN7DSTDIR=$(DOCS_SRC_DIR)/man7

# Manpages #1: Types
# Use shell / ls to get complete list - $(TYPEDIR)/*/man.rst does not work
# Using ls does not work if no file with given pattern exist, so use wildcard
MANTYPESRC=$(wildcard $(TYPEDIR)/*/man.rst)
MANTYPEPREFIX=$(subst $(TYPEDIR)/,$(MAN7DSTDIR)/cdist-type,$(MANTYPESRC))
MANTYPES=$(subst /man.rst,.rst,$(MANTYPEPREFIX))

# Link manpage: do not create man.html but correct named file
$(MAN7DSTDIR)/cdist-type%.rst: $(TYPEDIR)/%/man.rst
	ln -sf "../../../$^" $@

# Manpages #2: reference
DOCSREF=$(MAN7DSTDIR)/cdist-reference.rst
DOCSREFSH=$(DOCS_SRC_DIR)/cdist-reference.rst.sh

$(DOCSREF): $(DOCSREFSH)
	$(DOCSREFSH)

# Manpages #3: generic part
man: $(MANTYPES) $(DOCSREF) $(PYTHON_VERSION)
	$(SPHINXM)

html: $(MANTYPES) $(DOCSREF) $(PYTHON_VERSION)
	$(SPHINXH)

docs: man html

docs-clean:
	$(SPHINXC)

# Manpages #5: release part
MANWEBDIR=$(WEBBASE)/man/$(CHANGELOG_VERSION)
HTMLBUILDDIR=docs/dist/html

docs-dist: html
	rm -rf "${MANWEBDIR}"
	mkdir -p "${MANWEBDIR}"
	# mkdir -p "${MANWEBDIR}/man1" "${MANWEBDIR}/man7"
	# cp ${MAN1DSTDIR}/*.html ${MAN1DSTDIR}/*.css ${MANWEBDIR}/man1
	# cp ${MAN7DSTDIR}/*.html ${MAN7DSTDIR}/*.css ${MANWEBDIR}/man7
	cp -R ${HTMLBUILDDIR}/* ${MANWEBDIR}
	cd ${MANWEBDIR} && git add . && git commit -m "cdist manpages update: $(CHANGELOG_VERSION)" || true

man-latest-link: web-pub
	# Fix ikiwiki, which does not like symlinks for pseudo security
	ssh staticweb.ungleich.ch \
		"cd /home/services/www/nico/nico.schottelius.org/www/software/cdist/man/ && rm -f latest && ln -sf "$(CHANGELOG_VERSION)" latest"

# Manpages: .cdist Types
DOT_CDIST_PATH=${HOME}/.cdist
DOTMAN7DSTDIR=$(MAN7DSTDIR)
DOTTYPEDIR=$(DOT_CDIST_PATH)/type
DOTMANTYPESRC=$(wildcard $(DOTTYPEDIR)/*/man.rst)
DOTMANTYPEPREFIX=$(subst $(DOTTYPEDIR)/,$(DOTMAN7DSTDIR)/cdist-type,$(DOTMANTYPESRC))
DOTMANTYPES=$(subst /man.rst,.rst,$(DOTMANTYPEPREFIX))

# Link manpage: do not create man.html but correct named file
$(DOTMAN7DSTDIR)/cdist-type%.rst: $(DOTTYPEDIR)/%/man.rst
	ln -sf "$^" $@

# Manpages #3: generic part
dotman: $(DOTMANTYPES)
	$(SPHINXM)

################################################################################
# Speeches
#
SPEECHESOURCES=$(SPEECHDIR)/*.tex
SPEECHES=$(SPEECHESOURCES:.tex=.pdf)
SPEECHESWEBDIR=$(WEBBASE)/speeches

# Create speeches and ensure Toc is up-to-date
$(SPEECHDIR)/%.pdf: $(SPEECHDIR)/%.tex
	pdflatex -output-directory $(SPEECHDIR) $^
	pdflatex -output-directory $(SPEECHDIR) $^
	pdflatex -output-directory $(SPEECHDIR) $^

speeches: $(SPEECHES)

speeches-dist: speeches
	rm -rf "${SPEECHESWEBDIR}"
	mkdir -p "${SPEECHESWEBDIR}"
	cp ${SPEECHES} "${SPEECHESWEBDIR}"
	cd ${SPEECHESWEBDIR} && git add . && git commit -m "cdist speeches updated" || true

################################################################################
# Website
#

BLOGFILE=$(WEBBLOG)/cdist-$(CHANGELOG_VERSION)-released.mdwn

$(BLOGFILE): $(CHANGELOG_FILE)
	$(helper) blog $(CHANGELOG_VERSION) $(BLOGFILE)

web-blog: $(BLOGFILE)

web-doc:
	# Go to top level, because of cdist.mdwn
	rsync -av "$(WEBSRCDIR)/" "${WEBBASE}/.."
	cd "${WEBBASE}/.." && git add cdist* && git commit -m "cdist doc update" cdist* || true

web-dist: web-blog web-doc

web-pub: web-dist docs-dist speeches-dist
	cd "${WEBDIR}" && make pub

web-release-all: man-latest-link
web-release-all-no-latest: web-pub

################################################################################
# Release: Mailinglist
#
ML_FILE=.lock-ml

# Only send mail once - lock until new changelog things happened
$(ML_FILE): $(CHANGELOG_FILE)
	$(helper) ml-release $(CHANGELOG_VERSION)
	touch $@

ml-release: $(ML_FILE)


################################################################################
# pypi
#
PYPI_FILE=.pypi-release
$(PYPI_FILE): man $(PYTHON_VERSION)
	python3 setup.py sdist upload
	touch $@

pypi-release: $(PYPI_FILE)
################################################################################
# archlinux
#
ARCHLINUX_FILE=.lock-archlinux
ARCHLINUXTAR=cdist-$(CHANGELOG_VERSION)-1.src.tar.gz

$(ARCHLINUXTAR): PKGBUILD
	umask 022; mkaurball

PKGBUILD: PKGBUILD.in $(PYTHON_VERSION)
	./PKGBUILD.in $(CHANGELOG_VERSION)

$(ARCHLINUX_FILE): $(ARCHLINUXTAR) $(PYTHON_VERSION)
	burp -c system $(ARCHLINUXTAR)
	touch $@

archlinux-release: $(ARCHLINUX_FILE)

################################################################################
# Release
#

$(PYTHON_VERSION) version: .git/refs/heads/master
	$(helper) version

# Code that is better handled in a shell script
check-%:
	$(helper) $@

release:
	$(helper) $@

################################################################################
# Cleanup
#

clean:
	rm -f $(DOCS_SRC_DIR)/cdist-reference.rst

	find "$(DOCS_SRC_DIR)" -mindepth 2 -type l \
	| xargs rm -f

	make -C $(DOCS_SRC_DIR) clean

	find * -name __pycache__  | xargs rm -rf

	# Archlinux
	rm -f cdist-*.pkg.tar.xz cdist-*.tar.gz
	rm -rf pkg/ src/

	rm -f MANIFEST PKGBUILD
	rm -rf dist/

	# Signed release
	rm -f cdist-*.tar.gz
	rm -f cdist-*.tar.gz.asc

distclean: clean
	rm -f cdist/version.py

################################################################################
# Misc
#

# The pub is Nico's "push to all git remotes" way ("make pub")
pub:
	git push --mirror

test:
	$(helper) $@

test-remote:
	$(helper) $@

pep8:
	$(helper) $@
