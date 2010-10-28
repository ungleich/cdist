PREFIX=/usr
BINDIR=$(PREFIX}/bin

install:
	cp bin/* $(BINDIR)

sync:
	.rsync lyni@tablett:cdist
	.rsync nicosc@free.ethz.ch:cdist
