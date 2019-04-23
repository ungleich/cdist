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

CHANGELOG_VERSION=$(shell $(helper) changelog-version)
CHANGELOG_FILE=docs/changelog

PYTHON_VERSION=cdist/version.py

SPHINXM=make -C $(DOCS_SRC_DIR) man
SPHINXH=make -C $(DOCS_SRC_DIR) html
SPHINXC=make -C $(DOCS_SRC_DIR) clean

SHELLCHECKCMD=shellcheck -s sh -f gcc -x
# Skip SC2154 for variables starting with __ since such variables are cdist
# environment variables.
SHELLCHECK_SKIP=grep -v ': __.*is referenced but not assigned.*\[SC2154\]'
################################################################################
# Manpages
#
MAN7DSTDIR=$(DOCS_SRC_DIR)/man7

# Manpages #1: Types
# Use shell / ls to get complete list - $(TYPEDIR)/*/man.rst does not work
# Using ls does not work if no file with given pattern exist, so use wildcard
MANTYPESRC=$(wildcard $(TYPEDIR)/*/man.rst)
MANTYPEPREFIX=$(subst $(TYPEDIR)/,$(MAN7DSTDIR)/cdist-type,$(MANTYPESRC))
MANTYPES=$(subst /man.rst,.rst,$(MANTYPEPREFIX))

# Link manpage: do not create man.html but correct named file
$(MAN7DSTDIR)/cdist-type%.rst: $(TYPEDIR)/%/man.rst
	mkdir -p $(MAN7DSTDIR)
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

dotman: $(DOTMANTYPES)
	$(SPHINXM)

################################################################################
# Speeches
#
SPEECHESOURCES=$(SPEECHDIR)/*.tex
SPEECHES=$(SPEECHESOURCES:.tex=.pdf)

# Create speeches and ensure Toc is up-to-date
$(SPEECHDIR)/%.pdf: $(SPEECHDIR)/%.tex
	pdflatex -output-directory $(SPEECHDIR) $^
	pdflatex -output-directory $(SPEECHDIR) $^
	pdflatex -output-directory $(SPEECHDIR) $^

speeches: $(SPEECHES)

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

pycodestyle pep8:
	$(helper) $@

shellcheck-global-explorers:
	@find cdist/conf/explorer -type f -exec $(SHELLCHECKCMD) {} + | $(SHELLCHECK_SKIP) || exit 0

shellcheck-type-explorers:
	@find cdist/conf/type -type f -path "*/explorer/*" -exec $(SHELLCHECKCMD) {} + | $(SHELLCHECK_SKIP) || exit 0

shellcheck-manifests:
	@find cdist/conf/type -type f -name manifest -exec $(SHELLCHECKCMD) {} + | $(SHELLCHECK_SKIP) || exit 0

shellcheck-local-gencodes:
	@find cdist/conf/type -type f -name gencode-local -exec $(SHELLCHECKCMD) {} + | $(SHELLCHECK_SKIP) || exit 0

shellcheck-remote-gencodes:
	@find cdist/conf/type -type f -name gencode-remote -exec $(SHELLCHECKCMD) {} + | $(SHELLCHECK_SKIP) || exit 0

shellcheck-scripts:
	@$(SHELLCHECKCMD) scripts/cdist-dump || exit 0

shellcheck-gencodes: shellcheck-local-gencodes shellcheck-remote-gencodes

shellcheck-types: shellcheck-type-explorers shellcheck-manifests shellcheck-gencodes

shellcheck: shellcheck-global-explorers shellcheck-types shellcheck-scripts

shellcheck-type-files:
	@find cdist/conf/type -type f -path "*/files/*" -exec $(SHELLCHECKCMD) {} + | $(SHELLCHECK_SKIP) || exit 0

shellcheck-with-files: shellcheck shellcheck-type-files
