PREFIX=/usr
BINDIR=$(PREFIX}/bin

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
	cp REAL_README $$HOME/niconetz/software/cdist.mdwn

pub:
	git push --mirror
