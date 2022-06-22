.PHONY: installdeps git_cfg_safe srpm

installdeps:
	dnf -y install git autoconf automake make gettext-devel gcc

git_cfg_safe:
	# Workaround for CVE-2022-24765 fix:
	#
	#	fatal: unsafe repository ('/path' is owned by someone else)
	#
	# Since copr build process first clones the repo, and then uses mock to run the build
	#
	git config --global --add safe.directory "$(shell pwd)"

srpm: installdeps git_cfg_safe
	mkdir tmp.repos
	autopoint
	autoreconf -ivf
	./configure
	make dist
	rpmbuild \
		-D "_topdir tmp.repos" \
		-ts ./*.tar.gz
	cp tmp.repos/SRPMS/*.src.rpm $(outdir)
