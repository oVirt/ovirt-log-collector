#!/bin/bash -e
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
DB_NAME="report";
SOS_REPORT_UNPACK_DIR="${1}"
DBDIR="${SOS_REPORT_UNPACK_DIR}"/postgresDb
PGDATA="${DBDIR}"/pgdata
PGRUN="${DBDIR}"/pgrun
SQLS=$(dirname "${0}")/sqls
PSQL="psql --quiet --tuples-only --no-align --dbname $DB_NAME --username engine --host $PGRUN"

# PKI
ENGINE_PKI_CONF_DIR="/etc/ovirt-engine/engine.conf.d"
ENGINE_PKI_FILE="10-setup-pki.conf"
ENGINE_PKI_SETTINGS="${ENGINE_PKI_CONF_DIR}/${ENGINE_PKI_FILE}"
DEFAULT_PKI_TRUSTSTORE="/etc/pki/ovirt-engine/.truststore"

function printUsage() {
cat << __EOF__
Usage: $0 <analyzer_working_dir>

Script generates from db adoc file describing current system.
__EOF__

}

function execute_SQL_from_file() {
    ${PSQL} --file "$1";
}

function executeSQL() {
    ${PSQL} --command "$1";
}

function cleanup_db() {
    execute_SQL_from_file "${SQLS}"/cleanup.sql &> /dev/null
}

function bulletize() {
    sed "s/^/* /"
}

function enumerate() {
    sed "s/^/. /"
}

function createStatementExportingToCsvFromSelect() {
    echo "Copy ($1) To STDOUT With CSV DELIMITER E'${CSV_SEPARATOR}' HEADER;"
}

function printTable() {
    # Argument:
    #   SQL query
    #
    # Description:
    #   This function uses createStatementExportingToCsvFromSelect()
    #   to insert into SQL query the COPY() statement and save the SQL
    #   query output with CSV delimiter |. The delimiter | is used to
    #   create AsciiDoc tables and later converted to HTML tables.
    executeSQL "$(createStatementExportingToCsvFromSelect "$1")" | createAsciidocTable
}

#function you can pipe output into, and which rearrange data to produce asciidoc table.
# Creates an ascii doc table
    #
    # Args that affect adoc output:
    #     - If no argument, the header option will be
    #       included (first item displayed in bold)
    #
    #     - noheader, no additional option will be added
function createAsciidocTable() {
    if [[ ! -z ${1} && ${1} == "noheader" ]]; then
        echo "[options=\"\"]"
    else
        echo "[options=\"header\"]"
    fi

    echo "|===="
    while read A; do echo ${CSV_SEPARATOR}${A};done
    echo "|===="

}

function projectionCountingRowsWithOrder() {
    if [ $# -eq 0 ]; then
        #coding error

        echo "Coding error, supply at least one projection" >&2
        exit 1
    fi
    echo "row_number() OVER (ORDER BY $@ NULLs last) AS \"NO.\" "

}

function printSection() {
    echo
    echo "== $1"
}

function printFileHeader() {
echo '
= oVirt Report
:doctype: book
:source-highlighter: coderay
:listing-caption: Listing
:pdf-page-size: A4
:toc:
:icons: font
:OK: icon:check-circle-o[size=2x]
:WARNING: icon:exclamation-triangle[size=2x]
:INFO: icon:info-circle[size=2x]
:sectnums:
';
}

function initVariablesForVaryingNamesInSchema() {
    CLUSTER_TABLE=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM   information_schema.tables WHERE  table_name = 'vds_groups')) WHEN TRUE then 'vds_groups' else 'cluster' END AS name;" )
    NETWORK_ATTACHMENTS_TABLE_EXISTS=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM   information_schema.tables WHERE  table_name = 'network_attachments')) WHEN TRUE then 'exists' else 'does not exist' END AS name;")
    CLUSTER_PK_COLUMN=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vds_groups' AND column_name='vds_group_id')) WHEN TRUE then 'vds_group_id' else 'cluster_id' END AS name;" )
    VDS_CLUSTER_FK_COLUMN=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vds' AND column_name='vds_group_id')) WHEN TRUE THEN 'vds_group_id' else 'cluster_id' END AS name;" )
    VMS_CLUSTER_FK_COLUMN=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vms' AND column_name='vds_group_id')) WHEN TRUE THEN 'vds_group_id' else 'cluster_id' END AS name;" )
    VMS_CLUSTER_COMPATIBILITY_VERSION_COLUMN=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vms' AND column_name='vds_group_compatibility_version')) WHEN TRUE THEN 'vds_group_compatibility_version' else 'cluster_compatibility_version' END AS name;" )
    VDS_AGENT_IP_COLUMN=$(executeSQL "SELECT CASE (SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'vds' AND column_name='agent_ip')) WHEN TRUE THEN 'agent_ip' else 'ip' END AS name;" )
}

function list_rhn_channels() {
    # Look for the rhn channels based on yum_-C_repolist file from sosreport
    find "${SOS_REPORT_UNPACK_DIR}" -name yum_-C_repolist -exec tail -n +3 '{}' \; | cut -f 1 -d ' ' | sed -e '/repolist:/d' -e '/This/d' -e '/repo/d' | bulletize
}

function collect_rhn_data() {
    #
    # Reads /etc/sysconfig/rhn/systemid stored in sosreport
    # and returns the value assigned to the configuration key
    # provided as argument.
    #
    # Argument
    #     configuration key, example: system_id, username, etc
    PATH_SYSTEMID=$(find "${SOS_REPORT_UNPACK_DIR}" -name systemid)

    if [[ ! -z ${PATH_SYSTEMID} ]]; then
        xmlcmd="xmllint --xpath 'string(//member[* = \"$1\"]/value/string)' ${PATH_SYSTEMID}"
        # Withot a subshell the xmllint command complain, for now using sh -c
        sh -c "${xmlcmd}"
        echo
    fi
}
#-----------------------------------------------------------------------------------------------------------------------

if [ $# -ne 1 ]; then
    printUsage
    exit 1
fi

CSV_SEPARATOR=\|;

# Make sure nothing was left behind in case an exception happen during runtime
cleanup_db

execute_SQL_from_file "${SQLS}"/hosts_create_related_lookup_tables.sql
execute_SQL_from_file "${SQLS}"/storage_create_related_lookup_tables.sql
execute_SQL_from_file "${SQLS}"/vms_create_related_lookup_tables.sql

initVariablesForVaryingNamesInSchema

printFileHeader

printSection "Pre-upgrade checks"
. $(dirname "${0}")/pre-upgrade-checks

check_hosts_health
check_hosts_pretty_name
check_vms_health
check_cluster_no_dc
check_third_party_certificate
check_vms_running_obsolete_cluster
check_vms_with_no_timezone_set
check_mixedrhelversion
check_vds_groups_and_cluster_tables_coexist
check_vms_windows_with_incorrect_timezone
check_vms_linux_and_others_with_incorrect_timezone
check_vms_with_cluster_lower_3_6_with_virtio_serial_console
check_async_tasks
check_runnning_commands
check_compensation_tasks
check_storage_domains_failing

printSection "Engine details"

echo "{INFO} Before engine upgrades it is recommended to execute *engine-upgrade-check*"
echo

ENGINE_VERSIONS=$(execute_SQL_from_file "${SQLS}"/engine_versions_through_all_upgrades.sql)

echo ".Approximate version of initially installed engine"
ENGINE_FIRST_VERSION=$(echo "${ENGINE_VERSIONS}" | head -n 1)
echo ${ENGINE_FIRST_VERSION}
echo

echo ".Approximate current engine version"
ENGINE_CURRENT_VERSION=$(echo "${ENGINE_VERSIONS}" | tail -n 1)
echo ${ENGINE_CURRENT_VERSION}
echo

ENGINE_PAST_VERSIONS=$(echo "${ENGINE_VERSIONS}" | sort -u | sed -e s/"${ENGINE_CURRENT_VERSION}//")
if [ ${#ENGINE_PAST_VERSIONS} -gt 0 ]; then
    echo ".Probable past the engine versions as engine was upgraded in the past " \
         "footnote:[<We group the upgrade scripts by the time when the script was fully applied. " \
         "All scripts which finished in same 30 minutes span are considered to be " \
         "related to same upgrade. The last script then determines the version " \
         "of this 'upgrade'.>]"
    echo "${ENGINE_PAST_VERSIONS}" | bulletize
    echo
fi

echo ".Engine FQDN";
find "${SOS_REPORT_UNPACK_DIR}" -name "10-setup-protocols.conf" -exec grep "ENGINE_FQDN" '{}' \; | sed "s/^.*=//"
echo

DB_SIZE=$(execute_SQL_from_file "${SQLS}"/database_size.sql)
echo ".Engine DB size"
echo "${DB_SIZE}"
echo

user_rhn=$(collect_rhn_data "username")
id_rhn=$(collect_rhn_data "system_id")

if [ ${#user_rhn} -gt 0 ]; then
    printSection "RHN data from Engine"
    echo "*RHN Username*:"
    echo "${user_rhn}"
    echo
fi

if [ ${#id_rhn} -gt 0 ]; then
    echo "*RHN System id*:"
    echo "${id_rhn}"
    echo
fi

rhn_channels=$(list_rhn_channels)
if [[ ${#rhn_channels} -gt 0 && ${#user_rhn} -gt 0 ]]; then
    echo ".Engine subscribed channels"
    echo "${rhn_channels}"
fi
echo

printSection "Data Centers"
DC_QUERY=$(cat "${SQLS}"/datacenter_show_all.sql)
printTable "${DC_QUERY}"

printSection "Clusters"
printTable "SELECT
              $(projectionCountingRowsWithOrder c.name),
              c.name  AS \"Cluster Name\",
              sp.name AS \"Data Center Name\",
              c.compatibility_version AS \"Compatibility Version\"
            FROM
              $CLUSTER_TABLE c
              LEFT OUTER JOIN storage_pool sp ON c.storage_pool_id=sp.id
            ORDER BY c.name"

printSection "Virtual Machines"
TOTAL_NUMBER_OF_VMS=$(execute_SQL_from_file "${SQLS}/vms_query_total_number_of_virtual_machines_in_engine.sql")
TOTAL_WIN_VMS=$(execute_SQL_from_file "${SQLS}/vms_query_total_number_of_virtual_machines_windows_OS.sql")
TOTAL_LINUX_OR_OTHER_OS=$(execute_SQL_from_file "${SQLS}/vms_query_total_number_of_virtual_machines_linux_other_OS.sql")

echo -e ".Number of virtual machines per cluster:\n"
execute_SQL_from_file "${SQLS}"/cluster_query_vms_per_cluster.sql | createAsciidocTable

echo -e "Virtual machines with Linux OS or Other OS: *${TOTAL_LINUX_OR_OTHER_OS}*\n"
echo -e "Virtual machines with Windows Operational System: *${TOTAL_WIN_VMS}*\n"
echo -e "Total number of virtual machines in Engine: *${TOTAL_NUMBER_OF_VMS}*\n"

printSection "Hosts"
QUERY_HOSTS="SELECT
     $(projectionCountingRowsWithOrder c.name, v.vds_name),
     v.vds_name AS \"Name of Host\",
     coalesce(htt.text, 'Unknown (id='||v.vds_type||')') AS \"Host Type\",
     c.name AS \"Cluster\",
     c.name AS \"Data Center\",
     v.$VDS_AGENT_IP_COLUMN AS \"Agent IP\",
     v.host_name AS \"FQDN or IP\",
     regexp_replace(v.rpm_version, '[a-z]+.', '') AS \"vdsm\",
     v.kvm_version AS \"qemu-kvm\",
     regexp_replace(v.libvirt_version, '[a-z]+.', '') AS \"libvirt\",
     v.spice_version AS \"spice\",
     v.kernel_version AS \"kernel\",
     hst.text AS \"Status\",
     v.host_os AS \"Operating System\",
     v.vm_count AS \"VM Count\",
     v.mem_available AS \"Available memory\",
     v.usage_mem_percent AS \"Used memory %\",
     v.usage_cpu_percent AS \"CPU load %\"
   FROM
     vds v
     JOIN $CLUSTER_TABLE c ON c.$CLUSTER_PK_COLUMN=v.$VDS_CLUSTER_FK_COLUMN
     LEFT OUTER JOIN storage_pool sp ON c.storage_pool_id = sp.id
     LEFT OUTER JOIN host_status_temp hst ON hst.id = v.status
     LEFT OUTER JOIN host_type_temp htt ON htt.id = v.vds_type
   ORDER BY
     c.name, v.vds_name";
QUERY_HOSTS_AS_CSV=$(createStatementExportingToCsvFromSelect "$QUERY_HOSTS")

executeSQL "$QUERY_HOSTS_AS_CSV" | createAsciidocTable;

execute_SQL_from_file "${SQLS}/prepare_procedures_for_reporting_agent_passwords_as_csv.sql"
AGENT_PASSWORDS_QUERY=$(cat "${SQLS}"/agent_passwords.sql)
AGENT_PASSWORDS_AS_CSV=$(executeSQL "$(createStatementExportingToCsvFromSelect "$AGENT_PASSWORDS_QUERY")")
execute_SQL_from_file "${SQLS}/cleanup_procedures_for_reporting_agent_passwords_as_csv.sql"

#note gt 1, ie >1. It's because csv contains header, thus 0 records = 1 line.
if [ $(echo "${AGENT_PASSWORDS_AS_CSV}" | wc -l) -gt 1 ]; then
    printSection "Agent password per host"
    echo "${AGENT_PASSWORDS_AS_CSV}" | createAsciidocTable
fi

printSection "Storage Domains"

QUERY_STORAGE_DOMAIN="SELECT
      $(projectionCountingRowsWithOrder sds.storage_name),
      sds.storage_name AS \"Storage Domain\",
      stt.text AS \"Type\",
      sdtt.text AS \"Storage Domain Type\",
      sds.available_disk_size AS \"Available disk size (GB)\",
      sds.used_disk_size AS \"Used disk size (GB)\",
      sum(sds.available_disk_size + sds.used_disk_size) AS \"Total disk size (GB)\"
    FROM storage_domains sds
    JOIN storage_type_temp stt ON sds.storage_type=stt.id
    JOIN storage_domain_type_temp sdtt ON sds.storage_domain_type=sdtt.id
    GROUP BY sds.storage_name, sds.available_disk_size, sds.used_disk_size, stt.text, sdtt.text
    ORDER BY sds.storage_name"

QUERY_STORAGE_DOMAIN_AS_CSV=$(createStatementExportingToCsvFromSelect "$QUERY_STORAGE_DOMAIN" )

executeSQL "$CREATE_TEMP_TABLES_SQL $QUERY_STORAGE_DOMAIN_AS_CSV" | createAsciidocTable;

printSection "Data Warehouse (DWH)"
DWS_CHECK_RUUNING_QUERY=$(cat "${SQLS}"/dws_query_check_if_its_running.sql)
printTable "${DWS_CHECK_RUUNING_QUERY}"

printSection "Networks"

if [ "$NETWORK_ATTACHMENTS_TABLE_EXISTS" = "exists" ]; then
    NETWORKS_TABLE_QUERY=$(cat "${SQLS}"/networks_table_using_network_attachments.sql)
else
    NETWORKS_TABLE_QUERY=$(cat "${SQLS}"/networks_table_not_using_network_attachments.sql)
fi

printTable "$NETWORKS_TABLE_QUERY";

tablesWithOverriddenCompatibilityVersionSQL="SELECT
v.vm_name, v.$VMS_CLUSTER_COMPATIBILITY_VERSION_COLUMN
FROM vms v JOIN $CLUSTER_TABLE c ON c.$CLUSTER_PK_COLUMN=v.$VMS_CLUSTER_FK_COLUMN
WHERE v.$VMS_CLUSTER_COMPATIBILITY_VERSION_COLUMN <> c.compatibility_version"

if [ $(executeSQL "$tablesWithOverriddenCompatibilityVersionSQL" | wc -l) -gt 0 ]; then
  printSection "VMs with overridden cluster compatibility version"
  printTable "$tablesWithOverriddenCompatibilityVersionSQL"
fi

printSection "System Users"
printTable "SELECT
                $(projectionCountingRowsWithOrder surname, name),
                name  AS \"First Name\",
                surname  AS \"Last Name\",
                username  AS \"User name\",
                email  AS \"E-mail\"
            FROM
                users
            ORDER BY surname, name"

printSection "Main Packages installed in the Engine system:"
rpm_version "rhevm" | bulletize
rpm_version "engine" | bulletize
rpm_version "postgresql" | bulletize
rpm_version "spice" | bulletize

cleanup_db
