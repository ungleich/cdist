PREFIX=/usr
BINDIR=$(PREFIX}/bin
WEBDIR=$$HOME/niconetz
WEBPAGE=software/cdist.mdwn

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
