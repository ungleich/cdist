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

MAN1DST=$(addprefix $(MAN1DSTDIR)/,$(notdir $(MAN1SRC:.text=.1)))
MAN7DST=$(addprefix $(MAN7DSTDIR)/,$(notdir $(MAN7SRC:.text=.7)))
MANHTML=$(MAN1SRC:.text=.html) $(MAN7SRC:.text=.html)


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
	@echo '	clean: Remove build stuff'
	@echo ''
	@echo ''


################################################################################
# Documentation
#

# Create output dirs
$(MAN1DSTDIR) $(MAN7DSTDIR) $(MANHTMLDIR):
	mkdir -p $@

# Link source files
manlink: $(MAN1DSTDIR) $(MAN7DSTDIR)
	for mansrc in $(MAN1SRC); do ln -sf $$mansrc $(MAN1DSTDIR); done
	for mansrc in $(MAN7SRC); do ln -sf $$mansrc $(MAN7DSTDIR); done
	for mansrc in $(MAN7TYPESRC); do \
		dst="$$(echo $$mansrc | sed -e 's;conf/;cdist-;'  -e 's;/;;' -e 's;/man;;' -e 's;^;doc/man/man7/;')"; \
		ln -sf $$mansrc $$dst; done

%.1 %.7: %.text manlink
	$(A2XM) $*.text

%.html: %.text
	$(A2XH) -o $(MANHTMLDIR)/$(@F) $<

man: $(MAN1DST) $(MAN7DST)

html: $(MANHTML)

# man: doc/man/.marker

# Move into manpath directories
manmove: $(MAN1DST) $(MAN7DST) $(MANHTML)
	for manpage in $(MANDIR)/*.[1-9] conf/type/*/*.7; do \
		cat=$${manpage##*.}; \
		mandir=$(MANDIR)/man$$cat; \
		mkdir -p $$mandir; \
		mv $$manpage $$mandir; \
	done

	# HTML
	mkdir -p $(MANHTMLDIR)
	mv doc/man/*.html $(MANHTMLDIR)
	for mantype in conf/type/*/man.html; do \
		mannew=$$(echo $$mantype | sed -e 's;conf/;cdist-;'  -e 's;/;;' -e 's;/man;;');\
		mv $$mantype $(MANHTMLDIR)/$$mannew; \
	done

# Reference depends on conf/type/*/man.text - HOWTO with posix make?
$(MANDIR)/cdist-reference.text: $(MANDIR)/cdist-reference.text.sh
	$(MANDIR)/cdist-reference.text.sh
	$(A2XM) $(MANDIR)/cdist-reference.text
	$(A2XH) $(MANDIR)/cdist-reference.text
	
clean:
	rm -rf doc/man/html/* doc/man/*.[1-9] doc/man/man[1-9]
	rm -f conf/type/*/man.html $(MANDIR)/cdist-reference.text
	rm -rf $(MANHTMLDIR)

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
