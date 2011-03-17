# General
PREFIX=/usr
BINDIR=$(PREFIX)/bin
MANDIR=$(PREFIX)/share/man
A2X=a2x -f manpage --no-xmllint

# Developer only
WEBDIR=$$HOME/niconetz
WEBPAGE=software/cdist.mdwn

# Documentation
MANDIR=doc/man
MANGENERATED=$(MANDIR)/cdist-reference.text

MANSRC=$(MANDIR)/cdist.text						\
	$(MANDIR)/cdist-config.text 					\
   $(MANDIR)/cdist-dir.text         			\
   $(MANDIR)/cdist-env.text         			\
   $(MANDIR)/cdist-explorer-run-global.text 	\
   $(MANDIR)/cdist-deploy-to.text 				\
	$(MANDIR)/cdist-explorer.text					\
	$(MANDIR)/cdist-manifest.text 				\
	$(MANDIR)/cdist-quickstart.text 				\
	$(MANDIR)/cdist-stages.text					\
	$(MANDIR)/cdist-type.text						\
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
	@echo '	man: Build manpages (requires Asciidoc (a2x binary))'
	@echo '	clean: Remove build stuff'
	@echo ''
	@echo ''

man: doc/man/.marker

doc/man/.marker: $(MANDIR)/cdist-reference.text
	touch $@

# Manual from core
mancore: $(MANSRC)
	for mansrc in $^; do $(A2X) $$mansrc; done

# Manuals from types
mantype:
	for man in conf/type/*/man.text; do $(A2X) $$man; done

# Move into manpath directories
manmove: mantype mancore
	for manpage in $(MANDIR)/*.[1-9] conf/type/*/*.7; do \
		cat=$${manpage##*.}; \
		mandir=$(MANDIR)/man$$cat; \
		mkdir -p $$mandir; \
		mv $$manpage $$mandir; \
	done

# Reference depends on conf/type/*/man.text - HOWTO with posix make?
$(MANDIR)/cdist-reference.text: manmove $(MANDIR)/cdist-reference.text.sh
	$(MANDIR)/cdist-reference.text.sh
	$(A2X) $(MANDIR)/cdist-reference.text
	# Move us to the destination as well
	make manmove
	
clean:
	rm -rf doc/man/*.html doc/man/*.[1-9] doc/man/man[1-9] $(MANGENERATED)

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

web:
	cp README $(WEBDIR)/$(WEBPAGE)
	cd $(WEBDIR) && git commit -m "cdist update" $(WEBPAGE)
	cd $(WEBDIR) && make pub

pub:
	git push --mirror
	git push --mirror github
