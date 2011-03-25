#!/bin/sh
#
# 2011 Nico Schottelius (nico-cdist at schottelius.org)
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
# Push a directory to a target, both sides have the same name (i.e. explorers)
# or
# Pull a directory from a target, both sides have the same name (i.e. explorers)
#

# Manpage and HTML
A2XM="a2x -f manpage --no-xmllint"
A2XH="a2x -f xhtml --no-xmllint"

# Developer webbase
WEBDIR=$HOME/niconetz
WEBBASE=software/cdist
WEBPAGE=${WEBBASE}.mdwn

# Documentation
MANDIR=doc/man
MAN1DSTDIR=${MANDIR}/man1
MAN7DSTDIR=${MANDIR}/man7

MAN1SRC=                        				 	\
	${MANDIR}/cdist-code-run.text					\
	${MANDIR}/cdist-code-run-all.text			\
	${MANDIR}/cdist-config.text 					\
   ${MANDIR}/cdist-dir.text         			\
   ${MANDIR}/cdist-env.text         			\
   ${MANDIR}/cdist-explorer-run-global.text 	\
   ${MANDIR}/cdist-deploy-to.text 				\
	${MANDIR}/cdist-explorer.text					\
	${MANDIR}/cdist-manifest.text 				\
	${MANDIR}/cdist-manifest-run.text			\
   ${MANDIR}/cdist-manifest-run-init.text		\
   ${MANDIR}/cdist-manifest-run-all.text	 	\
	${MANDIR}/cdist-object-explorer-all.text	\
	${MANDIR}/cdist-object-gencode.text    	\
	${MANDIR}/cdist-object-gencode-all.text	\
   ${MANDIR}/cdist-remote-explorer-run.text 	\
	${MANDIR}/cdist-run-remote.text				\
	${MANDIR}/cdist-type-build-emulation.text \
	${MANDIR}/cdist-type-emulator.text			\
	${MANDIR}/cdist-type-template.text

MAN7SRC=${MANDIR}/cdist.text						\
	${MANDIR}/cdist-best-practise.text			\
	${MANDIR}/cdist-hacker.text  					\
	${MANDIR}/cdist-quickstart.text 				\
   ${MANDIR}/cdist-reference.text				\
	${MANDIR}/cdist-stages.text					\
	${MANDIR}/cdist-type.text						\


case "$1" in
   man)
	   for mansrc in ${MAN1SRC} ${MAN7SRC}; do
         ln -sf ../../../$mansrc ${MAN1DSTDIR};
      done
	   for mansrc in ${MAN7TYPESRC}; do
         dst="$(echo $mansrc | sed -e 's;conf/;cdist-;'  -e 's;/;;' -e 's;/man;;' -e 's;^;doc/man/man7/;')"
         ln -sf ../../../$$mansrc $$dst
      done
   ;;

   web)
      cp README ${WEBDIR}/${WEBPAGE}
      rm -rf ${WEBDIR}/${WEBBASE}/man && mkdir ${WEBDIR}/${WEBBASE}/man
      cp -r $(MANHTMLDIR)/* ${WEBDIR}/${WEBBASE}/man
      cd ${WEBDIR} && git add ${WEBBASE}/man
      cd ${WEBDIR} && git commit -m "cdist update" ${WEBBASE} ${WEBPAGE}
      cd ${WEBDIR} && make pub
   ;;

   pub)
      git push --mirror
      git push --mirror github
   ;;

   *)
      echo ''
      echo 'Welcome to cdist!'
      echo ''
      echo 'Here are the possible targets:'
      echo ''
      echo '	man: Build manpages (requires Asciidoc)'
      echo '	manhtml: Build html-manpages (requires Asciidoc)'
      echo '	clean: Remove build stuff'
      echo ''
      echo ''
      echo "Unknown target, \"$1\"" >&2
      exit 1
   ;;
esac


# Manpages from types
MAN7TYPESRC=$(ls conf/type/*/man.text)

# Source files after linking them
MAN1TMPSRC=$(shell ls ${MAN1DSTDIR}/*.text)
MAN7TMPSRC=$(shell ls ${MAN7DSTDIR}/*.text)

# Destination files based on linked files, not static list
MAN1DST=$(MAN1TMPSRC:.text=.1)
MAN7DST=$(MAN7TMPSRC:.text=.7)
MANHTML=$(MAN1TMPSRC:.text=.html) $(MAN7TMPSRC:.text=.html)

################################################################################
# User targets
#


################################################################################
# Documentation
#

# Create manpages
man: $(MAN1DST) $(MAN7DST)
manhtml: $(MANHTML)

$(MAN1DST) $(MAN7DST) $(MANHTML): $(MANOUTDIRS)

# Create output dirs
${MAN1DSTDIR} ${MAN7DSTDIR} $(MANHTMLDIR) $(MANTMPDIR):
	mkdir -p $@

# Link source files
manlink: ${MAN1SRC} ${MAN7SRC} $(MANTYPE7SRC) $(MANOUTDIRS)

%.1 %.7: %.text manlink
	$(A2XM) $*.text

%.html: %.text manlink
	$(A2XH) $<

${MANDIR}/cdist-reference.text: ${MANDIR}/cdist-reference.text.sh
	${MANDIR}/cdist-reference.text.sh
	
clean:
	rm -rf $(MANOUTDIRS)
	rm -f  ${MANDIR}/cdist-reference.text

################################################################################
# Developer targets
#

test:
	# ubuntu
	.rsync lyni@tablett:cdist
	# redhat
	.rsync nicosc@free.ethz.ch:cdist
	# gentoo
	.rsync nicosc@ru3.inf.ethz.ch:cdist
