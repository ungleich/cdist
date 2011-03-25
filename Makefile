# General
PREFIX=/usr
BINDIR=$(PREFIX)/bin
MANDIR=$(PREFIX)/share/man

# Manpage and HTML
A2XM=a2x -f manpage --no-xmllint
# A2XH=a2x -f xhtml --no-xmllint
A2XH=asciidoc -b xhtml11

# Developer only
WEBDIR=$$HOME/niconetz
WEBBASE=software/cdist
WEBPAGE=$(WEBBASE).mdwn


# Documentation
MANDIR=doc/man

MAN1DSTDIR=$(MANDIR)/man1
MAN7DSTDIR=$(MANDIR)/man7
MANHTMLDIR=$(MANDIR)/html
MANTMPDIR=$(MANDIR)/tmp
MANOUTDIRS=$(MAN1DSTDIR) $(MAN7DSTDIR) $(MANHTMLDIR)

MAN1SRC=                        				 	\
	$(MANDIR)/cdist-code-run.text					\
	$(MANDIR)/cdist-code-run-all.text			\
	$(MANDIR)/cdist-config.text 					\
   $(MANDIR)/cdist-dir.text         			\
   $(MANDIR)/cdist-env.text         			\
   $(MANDIR)/cdist-explorer-run-global.text 	\
   $(MANDIR)/cdist-deploy-to.text 				\
	$(MANDIR)/cdist-explorer.text					\
	$(MANDIR)/cdist-manifest.text 				\
	$(MANDIR)/cdist-manifest-run.text			\
   $(MANDIR)/cdist-manifest-run-init.text		\
   $(MANDIR)/cdist-manifest-run-all.text	 	\
	$(MANDIR)/cdist-object-explorer-all.text	\
	$(MANDIR)/cdist-object-gencode.text    	\
	$(MANDIR)/cdist-object-gencode-all.text	\
   $(MANDIR)/cdist-remote-explorer-run.text 	\
	$(MANDIR)/cdist-run-remote.text				\
	$(MANDIR)/cdist-type-build-emulation.text \
	$(MANDIR)/cdist-type-emulator.text			\
	$(MANDIR)/cdist-type-template.text			\

MAN7SRC=$(MANDIR)/cdist.text						\
	$(MANDIR)/cdist-best-practise.text			\
	$(MANDIR)/cdist-hacker.text  					\
	$(MANDIR)/cdist-quickstart.text 				\
   $(MANDIR)/cdist-reference.text				\
	$(MANDIR)/cdist-stages.text					\
	$(MANDIR)/cdist-type.text						\

MAN7TYPESRC=$(shell ls conf/type/*/man.text)
MAN7TYPEDST=$(shell for mansrc in $(MAN7TYPESRC:.text=.7); do dst="$$(echo $$mansrc | sed -e 's;conf/;cdist-;'  -e 's;/;;' -e 's;/man;;' -e 's;^;doc/man/man7/;')"; echo $$dst; done)
MAN1DST=$(addprefix $(MAN1DSTDIR)/,$(notdir $(MAN1SRC:.text=.1)))
MAN7DST=$(addprefix $(MAN7DSTDIR)/,$(notdir $(MAN7SRC:.text=.7)))
MANHTML=$(MAN1DST:.1=.html) $(MAN7DST:.7=.html) $(MAN7TYPEDST:.7=.html)


################################################################################
# User targets
#

all:
	@echo ''
	@echo 'Welcome to cdist!'
	@echo ''
	@echo 'Here are the possible targets:'
	@echo ''
	@echo '	man: Build manpages (requires Asciidoc)'
	@echo '	manhtml: Build html-manpages (requires Asciidoc)'
	@echo '	clean: Remove build stuff'
	@echo ''
	@echo ''


################################################################################
# Documentation
#

# Type manpages are in no good format for asciidoc, make them look good!
manlink: $(MANTMPDIR)
	for mansrc in $(MAN7TYPESRC); do \
		dst="$$(echo $$mansrc | sed -e 's;conf/;cdist-;'  -e 's;/;;' -e 's;/man;;' -e 's;^;$(MANTMPDIR)/;')"; \
		ln -sf ../../../$$mansrc $$dst; done
	for mansrc in $(MAN1SRC); do ln -sf ../../../$$mansrc $(MANTMPDIR); done
	for mansrc in $(MAN7SRC); do ln -sf ../../../$$mansrc $(MANTMPDIR); done

################################################################################

man: $(MAN1DST) $(MAN7DST) $(MAN7TYPEDST)

# Create output dirs
$(MAN1DSTDIR) $(MAN7DSTDIR) $(MANHTMLDIR) $(MANTMPDIR):
	mkdir -p $@

# Link source files
manlink: $(MAN1SRC) $(MAN7SRC) $(MANTYPE7SRC) $(MAN1DSTDIR) $(MAN7DSTDIR) $(MANHTMLDIR)
	for mansrc in $(MAN1SRC); do ln -sf ../../../$$mansrc $(MAN1DSTDIR); done
	for mansrc in $(MAN7SRC); do ln -sf ../../../$$mansrc $(MAN7DSTDIR); done
	for mansrc in $(MAN7TYPESRC); do \
		dst="$$(echo $$mansrc | sed -e 's;conf/;cdist-;'  -e 's;/;;' -e 's;/man;;' -e 's;^;doc/man/man7/;')"; \
		ln -sf ../../../$$mansrc $$dst; done

%.1 %.7: %.text manlink $(MANOUTDIRS)
	$(A2XM) $*.text

%.html: %.text manlink
	$(A2XH) -o $(MANHTMLDIR)/$(@F) $<

# $(MANHTML): $(MANHTMLDIR)
manhtml: $(MANHTML)

$(MANDIR)/cdist-reference.text: $(MANDIR)/cdist-reference.text.sh
	$(MANDIR)/cdist-reference.text.sh
	$(A2XM) $(MANDIR)/cdist-reference.text
	$(A2XH) $(MANDIR)/cdist-reference.text
	
clean:
	rm -rf doc/man/html/* doc/man/*.[1-9] doc/man/man[1-9]
	rm -f conf/type/*/man.html $(MANDIR)/cdist-reference.text
	rm -rf $(MAN1DSTDIR) $(MAN7DSTDIR) $(MANHTMLDIR)

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

web: manmove
	cp README $(WEBDIR)/$(WEBPAGE)
	rm -rf $(WEBDIR)/$(WEBBASE)/man && mkdir $(WEBDIR)/$(WEBBASE)/man
	cp -r $(MANHTMLDIR)/* $(WEBDIR)/$(WEBBASE)/man
	cd $(WEBDIR) && git add $(WEBBASE)/man
	cd $(WEBDIR) && git commit -m "cdist update" $(WEBBASE) $(WEBPAGE)
	cd $(WEBDIR) && make pub

pub:
	git push --mirror
	git push --mirror github
