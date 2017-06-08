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
Usage: $0 <analyzer_working_dir> <csv|adoc>

Script generates from db adoc or csv file describing current system.
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
    if [ -n "${ADOC}" ]; then
        sed "s/^/* /"
    else
        sed "s/^//"
    fi
}

function enumerate() {
    if [ -n "${ADOC}" ]; then
        sed "s/^/. /"
    else
        sed "s/^//"
    fi
}

function createStatementExportingToCsvFromSelect() {
    echo "Copy ($1) To STDOUT With CSV DELIMITER E'$2' HEADER;"
}

function printTable() {
    executeSQL "$(createStatementExportingToCsvFromSelect "$1" "$SEPARATOR_FOR_COLUMNS")" | createAsciidocTableWhenProducingAsciidoc
}

#function you can pipe output into, and which rearrange data to produce asciidoc table.
function createAsciidocTableWhenProducingAsciidoc() {
    # Creates an ascii doc table
    #
    # Args that affect adoc output:
    #     - If no argument, the header option will be
    #       included (first item displayed in bold)
    #
    #     - noheader, no additional option will be added
    if [ -n "${ADOC}" ]; then
        if [[ ! -z ${1} && ${1} == "noheader" ]]; then
            echo "[options=\"\"]"
        else
            echo "[options=\"header\"]"
        fi

        echo "|===="
        while read A; do echo $SEPARATOR_FOR_COLUMNS$A;done
        echo "|===="
    else
        while read A; do echo $A;done

    fi
}

function projectionCountingRowsWithOrder() {
    if [ $# -eq 0 ]; then
        #coding error
        exit 1
    fi
    echo "row_number() OVER (ORDER BY $@ NULLs last) AS \"NO.\" "

}

function printSection() {
    echo
    if [ -n "${ADOC}" ]; then
        echo "== $1"
    else
        echo "# $1"
    fi
}

function printFileHeader() {
    if [ -n "${ADOC}" ]; then
        echo '
= oVirt Report
:doctype: book
:source-highlighter: coderay
:listing-caption: Listing
:pdf-page-size: A4
:toc:
:toc-placement: preamble
:icons: font
:OK: icon:check-circle-o[size=2x]
:WARNING: icon:exclamation-triangle[size=2x]
:INFO: icon:info-circle[size=2x]
:sectnums:
    ';
    else
        echo "# oVirt Report"
    fi
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
#-----------------------------------------------------------------------------------------------------------------------

if [ $# -ne 2 ]; then
    printUsage
    exit 1
fi

if [ $2 = "csv" ]; then
    SEPARATOR_FOR_COLUMNS=,;
elif [ $2 = "adoc" ]; then
    ADOC=1;
    SEPARATOR_FOR_COLUMNS=\|;
else
    printUsage
    exit 1
fi

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

printSection "Data Centers"
execute_SQL_from_file "${SQLS}"/datacenter_show_all.sql | enumerate

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
QUERY_HOSTS_AS_CSV=$(createStatementExportingToCsvFromSelect "$QUERY_HOSTS" "$SEPARATOR_FOR_COLUMNS")

executeSQL "$QUERY_HOSTS_AS_CSV" | createAsciidocTableWhenProducingAsciidoc;

printSection "Storage Domains"

QUERY_STORAGE_DOMAIN="SELECT
      $(projectionCountingRowsWithOrder sds.storage_name),
      sds.storage_name AS \"Storage Domain\",
      stt.text AS \"Type\",
      sdtt.text AS \"Storage Domain Type\"
    FROM storage_domains sds
    JOIN storage_type_temp stt ON sds.storage_type=stt.id
    JOIN storage_domain_type_temp sdtt ON sds.storage_domain_type=sdtt.id
    ORDER BY sds.storage_name"

QUERY_STORAGE_DOMAIN_AS_CSV=$(createStatementExportingToCsvFromSelect "$QUERY_STORAGE_DOMAIN" "$SEPARATOR_FOR_COLUMNS")

executeSQL "$CREATE_TEMP_TABLES_SQL $QUERY_STORAGE_DOMAIN_AS_CSV" | createAsciidocTableWhenProducingAsciidoc;

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
