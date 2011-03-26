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

case "$1" in
   man)
      set -e
      "$0" mandirs
      "$0" mangen
      "$0" mantype
      "$0" man1
      "$0" man7
      "$0" manbuild
   ;;

   manbuild)
      for src in ${MAN1DSTDIR}/*.text ${MAN7DSTDIR}/*.text; do
         echo "Compiling manpage and html for $src"
         $A2XM "$src"
         $A2XH "$src"
      done
   ;;

   mandirs)
      # Create destination directories
      mkdir -p "${MAN1DSTDIR}" "${MAN7DSTDIR}"
   ;;

   mantype)
	   for mansrc in conf/type/*/man.text; do
         dst="$(echo $mansrc | sed -e 's;conf/;cdist-;'  -e 's;/;;' -e 's;/man;;' -e 's;^;doc/man/man7/;')"
         ln -sf "../../../$mansrc" "$dst"
      done
   ;;

   man1)
      for man in cdist-code-run.text cdist-code-run-all.text cdist-config.text \
         cdist-dir.text cdist-env.text cdist-explorer-run-global.text          \
         cdist-deploy-to.text cdist-explorer.text cdist-manifest.text          \
         cdist-manifest-run.text cdist-manifest-run-init.text                  \
         cdist-manifest-run-all.text cdist-object-explorer-all.text            \
         cdist-object-gencode.text cdist-object-gencode-all.text               \
         cdist-remote-explorer-run.text cdist-run-remote.text                  \
         cdist-type-build-emulation.text cdist-type-emulator.text              \
         cdist-type-template.text
         do
         ln -sf ../$man ${MAN1DSTDIR}
      done
   ;;

   man7)
      for man in cdist.text cdist-best-practice.text cdist-hacker.text         \
      cdist-quickstart.text cdist-reference.text cdist-stages.text             \
      cdist-type.text cdist-cache.text
         do
         ln -sf ../$man ${MAN7DSTDIR}
      done
   ;;

   mangen)
      ${MANDIR}/cdist-reference.text.sh
   ;;

   web)
      cp README ${WEBDIR}/${WEBPAGE}
      rm -rf ${WEBDIR}/${WEBBASE}/man && mkdir ${WEBDIR}/${WEBBASE}/man
      cp ${MAN1DSTDIR}/*.html ${MAN7DSTDIR}/*.html ${WEBDIR}/${WEBBASE}/man
      cd ${WEBDIR} && git add ${WEBBASE}/man
      cd ${WEBDIR} && git commit -m "cdist update" ${WEBBASE} ${WEBPAGE}
      cd ${WEBDIR} && make pub
   ;;

   pub)
      git push --mirror
      git push --mirror github
   ;;

   clean)
      rm -rf "$MAN1DSTDIR" "$MAN7DSTDIR"
      rm -f  ${MANDIR}/cdist-reference.text
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
