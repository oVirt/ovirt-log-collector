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
	unpackHostsSosReports.sh \
	vdsm-config-reader \
	inventory-profile \
	ovirt-log-collector-analyzer.sh \
	$(NULL)

produceReportdir=$(ovirtlogcollectoranalyzerdir)/produceReport
dist_produceReport_SCRIPTS = \
	produceReport/produceReport.sh \
	produceReport/pre-upgrade-checks \
	produceReport/security-checks \
	produceReport/docs-helper \
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
	produceReport/sqls/cluster_query_check_mixed_selinux_configs.sql \
	produceReport/sqls/cluster_query_minimum_3_6_compat_version.sql \
	produceReport/sqls/cluster_query_nonIBRS_CPUS.sql \
	produceReport/sqls/providers_query_show_data.sql \
	produceReport/sqls/hosts_query_check_health.sql \
	produceReport/sqls/storage_create_related_lookup_tables.sql \
	produceReport/sqls/engine_versions_through_all_upgrades.sql \
	produceReport/sqls/networks_table_not_using_network_attachments.sql \
	produceReport/sqls/vms_create_related_lookup_tables.sql \
	produceReport/sqls/vms_query_check_obsolete_cluster.sql \
	produceReport/sqls/dwh_query_check_if_its_running.sql \
	produceReport/sqls/vms_query_pinned_virtual_machines.sql \
	produceReport/sqls/hosts_query_check_pretty_name.sql \
	produceReport/sqls/database_size.sql \
	produceReport/sqls/vds_dynamic_check_for_net_config_dirty.sql \
	produceReport/sqls/storage_domains_query_get_failing_domains.sql \
	produceReport/sqls/vdc_options_query_checkmixedrhelversion.sql \
	produceReport/sqls/agent_passwords.sql \
	produceReport/sqls/network_query_cluster_with_non_ovirtmgmt_as_management_network.sql \
	produceReport/sqls/cleanup_procedures_for_reporting_agent_passwords_as_csv.sql \
	produceReport/sqls/prepare_procedures_for_reporting_agent_passwords_as_csv.sql \
	produceReport/sqls/business_entity_snapshot_query_running_compensation_tasks.sql \
	produceReport/sqls/vms_query_total_number_of_virtual_machines_windows_OS.sql \
	produceReport/sqls/vms_query_total_number_of_virtual_machines_in_engine.sql \
	produceReport/sqls/vms_query_total_number_of_virtual_machines_linux_other_OS.sql \
	produceReport/sqls/vms_query_with_nonIBRS_CPUS.sql \
	produceReport/sqls/cluster_query_vms_per_cluster.sql \
	produceReport/sqls/cluster_query_migration_policies.sql \
	produceReport/sqls/users_query_system_users.sql \
	produceReport/sqls/storage_domains_nfs_path.sql \
	produceReport/sqls/luns_query_all_data.sql \
	produceReport/sqls/storage_domains_lun_data.sql \
	produceReport/sqls/lun_storage_server_connection_map_query_number_connection_map.sql \
	produceReport/sqls/cluster_query_show_all_clusters.sql \
	produceReport/sqls/bookmarks_query_name_value.sql \
	produceReport/sqls/mac_pools_query_show_data_based_on_datacenter_and_cluster.sql \
	produceReport/sqls/vdc_options_query_AAA_legacy.sql \
	produceReport/sqls/datacenter_query_minimum_3_6_compat_version.sql \
	produceReport/sqls/storage_domains_query_data.sql \
	produceReport/sqls/images_query_invalid_status.sql \
	produceReport/sqls/images_query_vm_snapshot_id_zero.sql \
	produceReport/sqls/vdc_options_query_detect_hosted_engine_env.sql \
	produceReport/sqls/vds_statistics_query_ha_global_maintenance.sql \
	produceReport/sqls/vds_statistics_query_hosted_engine_setup_with_hosts_non_up.sql \
	produceReport/sqls/vms_query_ip_set_power_management_null.sql \
	produceReport/sqls/hosts_query_all.sql \
	produceReport/sqls/vms_query_snapshots_in_preview.sql \
	produceReport/sqls/hosts_query_number_of_hosts.sql \
	produceReport/sqls/hosts_cpu_Conroe_Penryn.sql \
	produceReport/sqls/vms_query_minimum_memory_guaranteed.sql \
	$(NULL)

EXTRA_DIST = \
	inventory-profile.in \
	$(NULL)

clean-local:
	rm -f inventory-profile

install-data-hook:
	$(MKDIR_P) "$(DESTDIR)$(bindir)"
	$(LN_S) "$(ovirtlogcollectoranalyzerdir)/ovirt-log-collector-analyzer.sh" "$(DESTDIR)$(bindir)/ovirt-log-collector-analyzer"
