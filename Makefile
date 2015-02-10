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

A2XM=a2x -f manpage --no-xmllint -a encoding=UTF-8
A2XH=a2x -f xhtml --no-xmllint -a encoding=UTF-8
# Create cross-links in html man pages
# We look for something like "cdist-type(7)" and make a href out of it
# The first matching group is the man page name and the second group
# is the man page section (1 or 7). The first three lines of the input
# (xml, DOCTYPE, head tags) are ignored, since the head tags contains
# the title of the page and should not contain a href.
CROSSLINK=sed --in-place '1,3!s/\([[:alnum:]_-]*\)(\([17]\))/<a href="..\/man\2\/\1.html">&<\/a>/g'
helper=./bin/build-helper

MANDIR=docs/man
SPEECHDIR=docs/speeches
TYPEDIR=cdist/conf/type

WEBSRCDIR=docs/web

WEBDIR=$$HOME/www.nico.schottelius.org
WEBBLOG=$(WEBDIR)/blog
WEBBASE=$(WEBDIR)/software/cdist
WEBPAGE=$(WEBBASE).mdwn

CHANGELOG_VERSION=$(shell $(helper) changelog-version)
CHANGELOG_FILE=docs/changelog

PYTHON_VERSION=cdist/version.py

################################################################################
# Manpages
#
MAN1DSTDIR=$(MANDIR)/man1
MAN7DSTDIR=$(MANDIR)/man7

# Manpages #1: Types
# Use shell / ls to get complete list - $(TYPEDIR)/*/man.text does not work
MANTYPESRC=$(shell ls $(TYPEDIR)/*/man.text)

# replace first path component
MANTYPEPREFIX=$(subst $(TYPEDIR)/,$(MAN7DSTDIR)/cdist-type,$(MANTYPESRC))

# replace man.text with .7 or .html
MANTYPEMAN=$(subst /man.text,.7,$(MANTYPEPREFIX))
MANTYPEHTML=$(subst /man.text,.html,$(MANTYPEPREFIX))
MANTYPEALL=$(MANTYPEMAN) $(MANTYPEHTML)

# Link manpage so A2XH does not create man.html but correct named file
$(MAN7DSTDIR)/cdist-type%.text: $(TYPEDIR)/%/man.text
	ln -sf "../../../$^" $@

# Manpages #2: reference
MANREF=$(MAN7DSTDIR)/cdist-reference.text
MANREFSH=$(MANDIR)/cdist-reference.text.sh
MANREFMAN=$(MANREF:.text=.7)
MANREFHTML=$(MANREF:.text=.html)
MANREFALL=$(MANREFMAN) $(MANREFHTML)

$(MANREF): $(MANREFSH)
	$(MANREFSH)

# Manpages #3: static pages
MAN1STATIC=$(shell ls $(MAN1DSTDIR)/*.text)
MAN7STATIC=$(shell ls $(MAN7DSTDIR)/*.text)
MANSTATICMAN=$(MAN1STATIC:.text=.1) $(MAN7STATIC:.text=.7)
MANSTATICHTML=$(MAN1STATIC:.text=.html) $(MAN7STATIC:.text=.html)
MANSTATICALL=$(MANSTATICMAN) $(MANSTATICHTML)

# Manpages #4: generic part

# Creating the type manpage
%.1 %.7: %.text
	$(A2XM) $^

# Creating the type html page
%.html: %.text
	$(A2XH) $^
	$(CROSSLINK) $@

man: $(MANTYPEALL) $(MANREFALL) $(MANSTATICALL)

# Manpages #5: release part
MANWEBDIR=$(WEBBASE)/man/$(CHANGELOG_VERSION)

man-dist: man check-date
	rm -rf "${MANWEBDIR}"
	mkdir -p "${MANWEBDIR}/man1" "${MANWEBDIR}/man7"
	cp ${MAN1DSTDIR}/*.html ${MAN1DSTDIR}/*.css ${MANWEBDIR}/man1
	cp ${MAN7DSTDIR}/*.html ${MAN7DSTDIR}/*.css ${MANWEBDIR}/man7
	cd ${MANWEBDIR} && git add . && git commit -m "cdist manpages update: $(CHANGELOG_VERSION)" || true

man-latest-link: web-pub
	# Fix ikiwiki, which does not like symlinks for pseudo security
	ssh tee.schottelius.org \
    	"cd /home/services/www/nico/www.nico.schottelius.org/www/software/cdist/man && rm -f latest && ln -sf "$(CHANGELOG_VERSION)" latest"

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

web-pub: web-dist man-dist speeches-dist
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

$(PYTHON_VERSION): .git/refs/heads/master
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
	rm -f $(MAN7DSTDIR)/cdist-reference.text

	find "$(MANDIR)" -mindepth 2 -type l \
	    -o -name "*.1" \
	    -o -name "*.7" \
	    -o -name "*.html" \
	    -o -name "*.xml" \
	| xargs rm -f

	find * -name __pycache__  | xargs rm -rf

	# Archlinux
	rm -f cdist-*.pkg.tar.xz cdist-*.tar.gz
	rm -rf pkg/ src/

	rm -f MANIFEST PKGBUILD
	rm -rf dist/

distclean: clean
	rm -f cdist/version.py

################################################################################
# Misc
#

# The pub is Nico's "push to all git remotes" way ("make pub")
pub:
	for remote in "" sf; do \
		echo "Pushing to $$remote"; \
		git push --mirror $$remote; \
	done

test:
	$(helper) $@
