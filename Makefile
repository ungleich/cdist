# General
PREFIX=/usr
BINDIR=$(PREFIX}/bin
A2X=a2x -f manpage --no-xmllint

# Developer only
WEBDIR=$$HOME/niconetz
WEBPAGE=software/cdist.mdwn

MANSRC=doc/man/cdist-config-layout.text \
	doc/man/cdist-config.text 		\
   doc/man/cdist-deploy-to.text 	\
	doc/man/cdist-explorer.text	\
	doc/man/cdist-manifest.text 	\
	doc/man/cdist-quickstart.text \
	doc/man/cdist-stages.text		\
	doc/man/cdist-terms.text 		\
	doc/man/cdist.text 				\
	doc/man/cdist-type.text


# FIXME: some distro nerd, can you make this more beautiful?
# I'm just a hacker, I don't really care...
install:
	cp bin/* $(BINDIR)

sync:
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

man: doc/man/.marker

doc/man/.marker: $(MANSRC)
	for man in $(MANSRC); do $(A2X) $$man; done
	touch $@

clean:
	rm -f doc/man/*.html doc/man/*.[1-9]
