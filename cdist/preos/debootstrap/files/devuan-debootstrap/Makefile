# avoid dpkg-dev dependency; fish out the version with sed
VERSION := $(shell sed 's/.*(\(.*\)).*/\1/; q' debian/changelog)

all:

clean:

DSDIR=$(DESTDIR)/usr/share/debootstrap
install:
	mkdir -p $(DSDIR)/scripts
	mkdir -p $(DESTDIR)/usr/sbin

	cp -a scripts/* $(DSDIR)/scripts/
	install -o root -g root -m 0644 functions $(DSDIR)/

	sed 's/@VERSION@/$(VERSION)/g' debootstrap >$(DESTDIR)/usr/sbin/debootstrap
	chown root:root $(DESTDIR)/usr/sbin/debootstrap
	chmod 0755 $(DESTDIR)/usr/sbin/debootstrap
