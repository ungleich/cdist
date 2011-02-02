PREFIX=/usr
BINDIR=$(PREFIX}/bin

install:
	cp bin/* $(BINDIR)

sync:
	.rsync lyni@tablett:cdist
	.rsync nicosc@free.ethz.ch:cdist

web:
	cp REAL_README $$HOME/niconetz/software/cdist.mdwn

pub:
	git push --mirror
