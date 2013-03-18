#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
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

config.py: \
	$(top_srcdir)/configure.ac \
	$(NULL)

SUBDIRS = sos helper

ovirtlogcollectorlib_PYTHON = \
	config.py\
	$(NULL)

dist_ovirtlogcollectorlib_PYTHON = \
	__init__.py \
	__main__.py \
	$(NULL)

dist_man_MANS = \
	engine-log-collector.8 \
	$(NULL)

dist_engineconfig_DATA = \
	logcollector.conf \
	$(NULL)

confddir=$(engineconfigdir)/logcollector.conf.d
dist_confd_DATA = \
	.keep \
	$(NULL)

all-local: \
	python-syntax-check \
	$(NULL)

clean-local: \
	python-clean \
	$(NULL)

install-data-hook:
	$(MKDIR_P) "$(DESTDIR)$(bindir)"
	chmod a+x "$(DESTDIR)$(ovirtlogcollectorlibdir)/__main__.py"
	rm -f "$(DESTDIR)$(bindir)/engine-log-collector"
	$(LN_S) "$(ovirtlogcollectorlibdir)/__main__.py" "$(DESTDIR)$(bindir)/engine-log-collector"

uninstall-hook:
	rm -f "$(DESTDIR)$(bindir)/engine-log-collector"
