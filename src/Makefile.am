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

include $(top_srcdir)/build/python.inc
include $(top_srcdir)/build/subst.inc

MAINTAINERCLEANFILES = \
	$(srcdir)/Makefile.in \
	$(NULL)

SUFFIXES = .in

CLEANFILES = \
	config.py \
	$(NULL)

EXTRA_DIST = \
	tests.py \
	$(NULL)

config.py: \
	$(top_srcdir)/configure.ac \
	$(NULL)

SUBDIRS = \
	helper \
	logrotate.d \
	$(NULL)

bin_SCRIPTS = \
	ovirt-log-collector \
	$(NULL)

ovirtlogcollectorlib_PYTHON = \
	config.py\
	$(NULL)

dist_ovirtlogcollectorlib_PYTHON = \
	__init__.py \
	__main__.py \
	$(NULL)

dist_man_MANS = \
	ovirt-log-collector.8 \
	$(NULL)

dist_engineconfig_DATA = \
	logcollector.conf \
	$(NULL)

confddir=$(engineconfigdir)/logcollector.conf.d

all-local: \
	python-syntax-check \
	$(NULL)

clean-local: \
	python-clean \
	$(NULL)

install-data-hook:
	$(MKDIR_P) "$(DESTDIR)$(confddir)"
	$(MKDIR_P) "$(DESTDIR)$(bindir)"
	$(MKDIR_P) "$(DESTDIR)$(localstatedir)/log/ovirt-engine/$(PACKAGE_NAME)"

uninstall-hook:
	rm -f "$(DESTDIR)$(bindir)/ovirt-log-collector"
