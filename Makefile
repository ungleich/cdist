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

################################################################################
# Manpages
#
MAN1DSTDIR=$(MANDIR)/man1
MAN7DSTDIR=$(MANDIR)/man7

# Manpages #1: Types
# Use shell / ls to get complete list - $(TYPEDIR)/*/man.text does not work
MANTYPESRC=$(shell ls $(TYPEDIR)/*/man.text)

# replace first path component
MANTYPEPREFIX=$(subst $(TYPEDIR),$(MAN7DSTDIR)/cdist-type,$(MANTYPESRC)) 

# replace man.text with .7 or .html
MANTYPEMAN=$(subst /man.text,.7,$(MANTYPEPREFIX)) 
MANTYPEHTML=$(subst /man.text,.html,$(MANTYPEPREFIX))
MANTYPEALL=$(TYPEMANPAGES) $(TYPEMANHTML)

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

man: $(MANTYPEALL) $(MANREFALL) $(MANSTATICALL)

# Manpages #5: release part
MANWEBDIR=$(WEBBASE)/man/$(CHANGELOG_VERSION)

man-git: man
	rm -rf "${MANWEBDIR}"
	mkdir -p "${MANWEBDIR}/man1" "${MANWEBDIR}/man7"
	cp ${MAN1DSTDIR}/*.html ${MAN1DSTDIR}/*.css ${MANWEBDIR}/man1
	cp ${MAN7DSTDIR}/*.html ${MAN7DSTDIR}/*.css ${MANWEBDIR}/man7
	cd ${MANWEBDIR} && git add . && git commit -m "cdist manpages update: $(CHANGELOG_VERSION)"

man-fix-link:
	# Fix ikiwiki, which does not like symlinks for pseudo security
	ssh tee.schottelius.org \
    	"cd /home/services/www/nico/www.nico.schottelius.org/www/software/cdist/man && rm -f latest && ln -sf "$(CHANGELOG_VERSION)" latest"

man-release: man web-release

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

speeches-release: speeches
	rm -rf "${SPEECHESWEBDIR}"
	mkdir -p "${SPEECHESWEBDIR}"
	cp ${SPEECHES} "${SPEECHESWEBDIR}"
	cd ${SPEECHESWEBDIR} && git add . && git commit -m "cdist speeches updated"

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

web-pub: web
	cd "${WEBDIR}" && make pub

web-release: web-blog web-doc
	cd "${WEBDIR}" && make pub

################################################################################
# Release && release check
#
CHECKS=check-version check-date check-unittest

DIST=dist-tag dist-branch-merge 

RELEASE=web-release release-man release-pypi release-archlinux-makepkg
RELEASE+=release-blog release-ml
RELEASE+=release-freecode release-archlinux-aur-upload

version=`git describe`
versionchangelog=`$(helper) changelog-version`
versionfile=cdist/version.py

archlinuxtar=cdist-${versionchangelog}-1.src.tar.gz

$(versionfile):
	$(helper) version


$(DIST): dist-check
$(RELEASE): $(DIST) $(CHECKS)

# Code that is better handled in a shell script
check-%:
	$(helper) $@

# Pub is Nico's "push to all git remotes" thing
pub:
	for remote in "" github sf; do \
		echo "Pushing to $$remote" \
		git push --mirror $$remote \
	done  

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
#release: pub $(RELEASE)
release: release-man
	echo "Don't forget...: linkedin"


release-archlinux: $(archlinuxtar)
	burp -c system $^
	
release-blog: blog
release-ml: release-blog
release-pub: man

PKGBUILD: PKGBUILD.in
	./PKGBUILD.in

################################################################################
# Cleanup

clean:
	rm -f $(MAN7DSTDIR)/cdist-reference.text

	find "$(MANDIR)" -mindepth 2 -type l \
	    -o -name "*.1" \
	    -o -name "*.7" \
	    -o -name "*.html" \
	    -o -name "*.xml" \
	| xargs rm -f

	find * -name __pycache__  | xargs rm -rf 

distclean:
	rm -f cdist/version.py MANIFEST PKGBUILD
	rm -rf cache/ dist/

	# Archlinux
	rm -f cdist-*.pkg.tar.xz cdist-*.tar.gz
	rm -rf pkg/ src/
