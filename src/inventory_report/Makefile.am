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
	produceReport/sqls/vms_query_linux_and_others_vms_with_incorrect_timezone.sql \
	produceReport/sqls/datacenter_show_all.sql \
	produceReport/sqls/async_tasks_query_running_tasks.sql \
	produceReport/sqls/command_entities_query_get_running_commands.sql \
	produceReport/sqls/vms_with_cluster_lower_3_6_with_virtio_serial_console.sql \
	produceReport/sqls/vms_query_windows_vms_with_incorrect_timezone.sql \
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
	produceReport/sqls/vms_check_no_timezone_set.sql \
	produceReport/sqls/hosts_query_check_pretty_name.sql \
	produceReport/sqls/database_size.sql \
	produceReport/sqls/storage_domains_query_get_failing_domains.sql \
	produceReport/sqls/vdc_options_query_checkmixedrhelversion.sql \
	produceReport/sqls/agent_passwords.sql \
	produceReport/sqls/cleanup_procedures_for_reporting_agent_passwords_as_csv.sql \
	produceReport/sqls/prepare_procedures_for_reporting_agent_passwords_as_csv.sql \
	produceReport/sqls/business_entity_snapshot_query_running_compensation_tasks.sql \
	produceReport/sqls/vms_query_total_number_of_virtual_machines_windows_OS.sql \
	produceReport/sqls/vms_query_total_number_of_virtual_machines_in_engine.sql \
	produceReport/sqls/vms_query_total_number_of_virtual_machines_linux_other_OS.sql \
	produceReport/sqls/cluster_query_vms_per_cluster.sql \
	produceReport/sqls/storage_domains_query_number_of_disks.sql \
	produceReport/sqls/cluster_query_migration_policies.sql \
	$(NULL)

install-data-hook:
	$(MKDIR_P) "$(DESTDIR)$(bindir)"
	$(LN_S) "$(ovirtlogcollectoranalyzerdir)/ovirt-log-collector-analyzer.sh" "$(DESTDIR)$(bindir)/ovirt-log-collector-analyzer"
