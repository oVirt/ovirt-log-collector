.PHONY: installdeps srpm

installdeps:
	dnf -y install git autoconf automake make gettext-devel gcc

srpm: installdeps
	mkdir tmp.repos
	autopoint
	autoreconf -ivf
	./configure
	make dist
	rpmbuild \
		-D "_topdir tmp.repos" \
		-ts ./*.tar.gz
	cp tmp.repos/SRPMS/*.src.rpm $(outdir)
