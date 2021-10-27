#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

AUTOMAKE_OPTIONS = foreign 1.9
ACLOCAL_AMFLAGS = -I m4

MAINTAINERCLEANFILES = \
	config.log config.status \
	$(srcdir)/Makefile.in \
	$(srcdir)/configure \
	$(srcdir)/install-sh $(srcdir)/missing $(srcdir)/py-compile \
	$(srcdir)/depcomp \
	$(srcdir)/config.guess $(srcdir)/config.sub \
	$(srcdir)/config.rpath \
	$(srcdir)/ABOUT-NLS \
	$(srcdir)/aclocal.m4 \
	$(NULL)


EXTRA_DIST = \
	.gitignore \
	m4/.gitignore \
	po/.gitignore \
	README.localization \
	README.md \
	COPYING-GPL \
	$(NULL)

SUBDIRS = \
	po \
	src \
	$(NULL)

dist_noinst_DATA = \
	ovirt-log-collector.spec \
	$(NULL)

dist_noinst_SCRIPTS = \
	autogen.sh \
	$(NULL)

TMPREPOS = tmp.repos
srpm:	dist
	rm -fr "$(TMPREPOS)"
	mkdir -p $(TMPREPOS)/{SPECS,RPMS,SRPMS,SOURCES}
	rpmbuild --define="_topdir `pwd`/$(TMPREPOS)" -ts "$(PACKAGE_TARNAME)-$(PACKAGE_VERSION).tar.gz"
	@echo
	@echo "srpm available at '$(TMPREPOS)'"
	@echo

rpm:	srpm
	rpmbuild --define="_topdir `pwd`/$(TMPREPOS)" --rebuild "$(TMPREPOS)"/SRPMS/*.src.rpm
	@echo
	@echo "rpm(s) available at '$(TMPREPOS)'"
	@echo

clean-local:
	rm -fr "$(TMPREPOS)"

maintainer-clean-local:
	sed '/^$$/d' "$(srcdir)/m4/.gitignore" | while read f; do \
		rm -f $(srcdir)/m4/$$f; \
	done
	sed '/^$$/d' "$(srcdir)/po/.gitignore" | while read f; do \
		rm -f $(srcdir)/po/$$f po/$$f; \
	done

POTFILES.in:
	( cd "$(srcdir)" && \
		find ./src -name '*.py' -or -name '*.py.in' ) | \
		sort | grep -v config.py > POTFILES.in.tmp && \
	cmp -s POTFILES.in.tmp "$(srcdir)/po/POTFILES.in" || \
		cp POTFILES.in.tmp "$(srcdir)/po/POTFILES.in"; \
	rm -f POTFILES.in.tmp

update-po: POTFILES.in
	$(MAKE) -C po update-po
