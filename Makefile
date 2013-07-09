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

MAN1DSTDIR=$(MANDIR)/man1
MAN7DSTDIR=$(MANDIR)/man7
MANREF=$(MAN7DSTDIR)/cdist-reference.text
MANREFSH=$(MANDIR)/cdist-reference.text.sh

SPEECHDIR=docs/speeches

TYPEDIR=cdist/conf/type

################################################################################
# Manpages for types
#
# Use shell / ls to get complete list - $(TYPEDIR)/*/man.text does not work
TYPEMANSRC=$(shell ls $(TYPEDIR)/*/man.text)

# replace first path component
TYPEMANPREFIX=$(subst cdist/conf/type/,docs/man/man7/cdist-type,$(TYPEMANSRC)) 

# replace man.text with .7 or .html
TYPEMANPAGES=$(subst /man.text,.7,$(TYPEMANPREFIX)) 
TYPEMANHTML=$(subst /man.text,.html,$(TYPEMANPREFIX))


# Link manpage so A2XH does not create man.html but correct named file
$(MAN7DSTDIR)/cdist-type%.text: $(TYPEDIR)/%/man.text
	ln -sf "../../../$^" $@

# Creating the type manpage
$(MAN7DSTDIR)/cdist-type%.7: $(MAN7DSTDIR)/cdist-type%.text
	$(A2XM) $^

# Creating the type html page
$(MAN7DSTDIR)/cdist-type%.html: $(MAN7DSTDIR)/cdist-type%.text
	$(A2XH) $^

typemanpage: $(TYPEMANPAGES)
typemanhtml: $(TYPEMANHTML)

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
CHECKS=check-version check-date

DIST=dist-tag dist-branch-merge 

RELEASE=release-web release-man release-pypi release-archlinux-makepkg
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

man: $(MANREF) mantype manbuild

$(MANREF): $(MANREFSH)
	$(MANREFSH)

################################################################################
# manpage
# generate links from types
# build manpages
#

mantypedocuments=cdist/conf/type/*/man.text

mantypelist: $(mantypedocuments)
	echo $^ >> $@

link-type-manpages:
	$(helper) $@


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


################################################################################
# generic call
%:
	$(helper) $@
