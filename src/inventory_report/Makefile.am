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
	unpackAndPrepareDump.sh \
	ovirt-log-collector-analyzer.sh \
	$(NULL)

produceReportdir=$(ovirtlogcollectoranalyzerdir)/produceReport
dist_produceReport_SCRIPTS = \
	produceReport/produceReport.sh \
	produceReport/pre-upgrade-checks \
	$(NULL)

dist_ovirtlogcollectoranalyzer_DATA = \
	$(NULL)

sqldir=$(produceReportdir)/sqls
dist_sql_SCRIPTS = \
	produceReport/sqls/cleanup.sql \
	produceReport/sqls/hosts_create_related_lookup_tables.sql \
	produceReport/sqls/networks_table_using_network_attachments.sql \
	produceReport/sqls/vms_query_health.sql \
	produceReport/sqls/cluster_query_check_datacenter.sql \
	produceReport/sqls/hosts_query_check_health.sql \
	produceReport/sqls/storage_create_related_lookup_tables.sql \
	produceReport/sqls/engine_versions_through_all_upgrades.sql \
	produceReport/sqls/networks_table_not_using_network_attachments.sql \
	produceReport/sqls/vms_create_related_lookup_tables.sql \
	produceReport/sqls/vms_query_check_obsolete_cluster.sql \
	produceReport/sqls/dws_query_check_if_its_running.sql \
	$(NULL)

install-data-hook:
	$(MKDIR_P) "$(DESTDIR)$(bindir)"
	$(LN_S) "$(ovirtlogcollectoranalyzerdir)/ovirt-log-collector-analyzer.sh" "$(DESTDIR)$(bindir)/ovirt-log-collector-analyzer"
