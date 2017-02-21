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

include $(top_srcdir)/build/subst.inc

MAINTAINERCLEANFILES = \
	$(srcdir)/Makefile.in \
	$(NULL)

SUFFIXES = .in

dist_ovirtlogcollectoranalyzer_SCRIPTS = \
	importDumpIntoNewDb.sh \
	produceReport.sh \
	unpackAndPrepareDump.sh \
	ovirt-log-collector-analyzer.sh \
	$(NULL)

dist_ovirtlogcollectoranalyzer_DATA = \
	$(NULL)

install-data-hook:
	$(MKDIR_P) "$(DESTDIR)$(bindir)"
	$(LN_S) "$(ovirtlogcollectoranalyzerdir)/ovirt-log-collector-analyzer.sh" "$(DESTDIR)$(bindir)/ovirt-log-collector-analyzer"
