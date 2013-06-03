DIST=dist-tag dist-branch-merge dist-pypi dist-archlinux-makepkg
PUBLISH=web man-pub pub dist-blog dist-freecode dist-ml dist-manual dist-archlinux-aur-upload


%:
	./build-cdist $@

$(DIST): dist-check

dist: $(DIST)
	echo "Run \"make release\" to release to the public"

release:
