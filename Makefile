# General
PREFIX=/usr
BINDIR=$(PREFIX)/bin
MANDIR=$(PREFIX)/share/man

# Manpage and HTML
A2XM=a2x -f manpage --no-xmllint
# A2XH=a2x -f xhtml --no-xmllint
A2XH=asciidoc -b xhtml11

# Developer only
WEBPAGEBASE=$$HOME/niconetz/software/cdist
WEBPAGE=$(WEBPAGEBASE).mdwn

# Documentation
MANDIR=doc/man
MANGENERATED=$(MANDIR)/cdist-reference.text

MANSRC=$(MANDIR)/cdist.text						\
	$(MANDIR)/cdist-code-run-all.text			\
	$(MANDIR)/cdist-code-run.text					\
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
	$(MANDIR)/cdist-quickstart.text 				\
   $(MANDIR)/cdist-remote-explorer-run.text 	\
	$(MANDIR)/cdist-run-remote.text				\
	$(MANDIR)/cdist-stages.text					\
	$(MANDIR)/cdist-type.text						\
	$(MANDIR)/cdist-type-build-emulation.text \
	$(MANDIR)/cdist-type-emulator.text			\
	$(MANDIR)/cdist-type-template.text			\


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

man: doc/man/.marker

doc/man/.marker: $(MANDIR)/cdist-reference.text
	touch $@

# Manual from core
mancore: $(MANSRC)
	for mansrc in $^; do $(A2XM) $$mansrc; $(A2XH) $$mansrc; done

# Manuals from types
mantype:
	for man in conf/type/*/man.text; do $(A2XM) $$man; $(A2XH) $$man; done

# Move into manpath directories
manmove: mantype mancore
	for manpage in $(MANDIR)/*.[1-9] conf/type/*/*.7; do \
		cat=$${manpage##*.}; \
		mandir=$(MANDIR)/man$$cat; \
		mkdir -p $$mandir; \
		mv $$manpage $$mandir; \
	done
	mkdir -p doc/html
	mv doc/man/*.html doc/html

	for mantype in conf/type/*/man.html; do \
	mannew=$$(echo $$mantype | sed -e 's;conf/;cdist-;'  -e 's;/;;' -e 's;/man;;');\
	mv $$mantype doc/html/$$mannew; \
	done

# Reference depends on conf/type/*/man.text - HOWTO with posix make?
$(MANDIR)/cdist-reference.text: manmove $(MANDIR)/cdist-reference.text.sh
	$(MANDIR)/cdist-reference.text.sh
	$(A2XM) $(MANDIR)/cdist-reference.text
	$(A2XH) $(MANDIR)/cdist-reference.text
	# Move us to the destination as well
	make manmove
	
clean:
	rm -rf doc/man/*.html doc/man/*.[1-9] doc/man/man[1-9] $(MANGENERATED)
	rm -f conf/type/*/man.html
	rm -rf doc/html

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

#web: manmove
web:
	cp README $(WEBPAGE)
	cp -r doc/html/* $(WEBPAGEBASE)/man
	cd $(WEBDIR) && git commit -m "cdist update" $(WEBPAGEBASE)
	cd $(WEBDIR) && make pub

pub:
	git push --mirror
	git push --mirror github
