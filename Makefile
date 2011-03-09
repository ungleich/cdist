# General
PREFIX=/usr
BINDIR=$(PREFIX)/bin
MANDIR=$(PREFIX)/share/man
A2X=a2x -f manpage --no-xmllint

# Developer only
WEBDIR=$$HOME/niconetz
WEBPAGE=software/cdist.mdwn

MANDIR=doc/man
MANSRC=$(MANDIR)/cdist-config-layout.text \
	$(MANDIR)/cdist-config.text 		\
	$(MANDIR)/cdist-explorer.text	\
	$(MANDIR)/cdist-quickstart.text \
	$(MANDIR)/cdist-stages.text		\
	$(MANDIR)/cdist-terms.text 		\

MANGENERATED=$(MANDIR)/cdist-reference.text

MANSRC=$(MANDIR)/cdist.text				\
   $(MANDIR)/cdist-bin-transfer.text	\
   $(MANDIR)/cdist-deploy-to.text 		\
	$(MANDIR)/cdist-manifest.text 		\
	$(MANDIR)/cdist-stages.text			\
	$(MANDIR)/cdist-type.text				\
	$(MANDIR)/cdist-type-template.text	\
	$(MANDIR)/cdist-type__file.text		\


################################################################################
# User targets
#

all:
	@echo ''
	@echo 'Welcome to cdist!'
	@echo ''
	@echo 'Here are the possible targets:'
	@echo ''
	@echo '	man: Build manpages'
	@echo '	clean: Remove build stuff'
	@echo ''
	@echo ''

man: doc/man/.marker

doc/man/.marker: $(MANSRC) $(MANGENERATED)
	for mansrc in $^; do $(A2X) $$mansrc; done
	for manpage in $(MANDIR)/*.[1-9]; do cat=$${manpage##*.}; mandir=$(MANDIR)/man$$cat; mkdir -p $$mandir; mv $$manpage $$mandir; done
	touch $@

# Only depends on cdist-type__*.text in reality
$(MANDIR)/cdist-reference.text: $(MANSRC) $(MANDIR)/cdist-reference.text.sh
	$(MANDIR)/cdist-reference.text.sh
	

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
	cp REAL_README $(WEBDIR)/$(WEBPAGE)
	cd $(WEBDIR) && git commit -m "cdist update" $(WEBPAGE)
	cd $(WEBDIR) && make pub

pub:
	git push --mirror
