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

.PHONY: help
help:
	@echo "Please use \`make <target>' where <target> is one of"
	@echo "man             build only man user documentation"
	@echo "html            build only html user documentation"
	@echo "docs            build both man and html user documentation"
	@echo "dotman          build man pages for types in your ~/.cdist directory"
	@echo "speeches        build speeches pdf files"
	@echo "install         install in the system site-packages directory"
	@echo "install-user    install in the user site-packages directory"
	@echo "docs-clean      clean documentation"
	@echo "clean           clean"

DOCS_SRC_DIR=./docs/src
SPEECHDIR=./docs/speeches
TYPEDIR=./cdist/conf/type

SPHINXM=$(MAKE) -C $(DOCS_SRC_DIR) man
SPHINXH=$(MAKE) -C $(DOCS_SRC_DIR) html
SPHINXC=$(MAKE) -C $(DOCS_SRC_DIR) clean

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

# Html types list with references
DOCSTYPESREF=$(MAN7DSTDIR)/cdist-types.rst
DOCSTYPESREFSH=$(DOCS_SRC_DIR)/cdist-types.rst.sh

$(DOCSTYPESREF): $(DOCSTYPESREFSH)
	$(DOCSTYPESREFSH)

DOCSCFGSKEL=./configuration/cdist.cfg.skeleton

configskel: $(DOCSCFGSKEL)
	cp -f "$(DOCSCFGSKEL)" "$(DOCS_SRC_DIR)/"

version:
	@[ -f "cdist/version.py" ] || { \
		printf "Missing 'cdist/version.py', please generate it first.\n" && exit 1; \
	}

# Manpages #3: generic part
man: version configskel $(MANTYPES) $(DOCSREF) $(DOCSTYPESREF)
	$(SPHINXM)

html: version configskel $(MANTYPES) $(DOCSREF) $(DOCSTYPESREF)
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

dotman: version configskel $(DOTMANTYPES) $(DOCSREF) $(DOCSTYPESREF)
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
# Misc
#
clean: docs-clean
	rm -f $(DOCS_SRC_DIR)/cdist-reference.rst
	rm -f $(DOCS_SRC_DIR)/cdist-types.rst
	rm -f $(DOCS_SRC_DIR)/cdist.cfg.skeleton

	find "$(DOCS_SRC_DIR)" -mindepth 2 -type l \
	| xargs rm -f

	find * -name __pycache__  | xargs rm -rf

	# distutils
	rm -rf ./build

################################################################################
# install
#

install:
	python3 setup.py install

install-user:
	python3 setup.py install --user
