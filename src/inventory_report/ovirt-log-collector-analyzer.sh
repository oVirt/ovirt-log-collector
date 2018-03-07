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
SCRIPT_DIR="$(dirname $(readlink -f $0))"
WORK_DIR="$(mktemp -d)"

. ${SCRIPT_DIR}/inventory-profile
mkdir -p ${HOSTS_SOSREPORT_EXTRACTED_DIR}

function usage() {
cat << __EOF__
Usage: $0 [options] <tar-file>
    --postgres-db-user
        Postgres username for database connection (only required for remote database)
    --postgres-db-address
        Postgres database address (only required for remote database)
    --postgres-db-password
        Postgres database password (only required for remote database)
    --temporary-db-name
        Name for temporary database which will import the Engine db dump (if not provided, random name will be generated)
    --keep-working-dir
        Do not remove the temporary working directory in the end.
    --show-fence-agent-passwords
        Show fence agent encrypted passwords per host
    --summary
        Executive summary, do not execute pre-upgrade validation
    --html=<file>
        Write html report to <file>. Defaults to ${HTML_OUT} .
    --version
        Report application version and exit

Script unpacks sosreport, import it into db and generates html report into current directory.
__EOF__
exit 1;

}

function version() {
    echo "$ANALYZER_VERSION-$ANALYZER_RELEASE (git $ANALYZER_GITHEAD)"
    exit 0
}

KEEP_WORKING_DIR=
REPORT_ONLY=
TAR_FILE=
HTML_OUT=analyzer_report.html

# Postgres data
ENGINE_DB_USER="ENGINE_DB_USER=engine"

# Generate random 10 character alphanumeric string (lowercase)
TEMPORARY_DB_NAME="TEMPORARY_DB_NAME=report$(openssl rand -hex 10)"

while [ -n "$1" ]; do
    x="$1"
    v="${x#*=}"
    shift
    case "${x}" in
            --help)
                usage
                ;;
            --postgres-db-user=*)
                PG_DB_USER="PG_DB_USER=${v}"
                ;;
            --postgres-db-address=*)
                PG_DB_ADDRESS="PG_DB_ADDRESS=${v}"
                ;;
            --postgres-db-password=*)
                PG_DB_PASSWORD="PG_DB_PASSWORD=${v}"
                ;;
            --keep-working-dir)
                KEEP_WORKING_DIR=1
                ;;
            --summary)
                SUMMARY_REPORT+="SUMMARY_REPORT=true"
                ;;
            --show-fence-agent-passwords)
                SHOW_FENCE_AGENT_PASSWORDS+="SHOW_FENCE_AGENT_PASSWORDS=true"
                ;;
            --temporary-db-name=*)
                TEMPORARY_DB_NAME="TEMPORARY_DB_NAME=${v}"
                ;;
            --html=*)
                HTML_OUT="${v}"
                ;;
            --version)
                version
                ;;
            *)
                if [ -r "${x}" ]; then
                    TAR_FILE="$(readlink -f "${x}")"
                else
                    echo "Invalid option '${x}'"
                    exit 1
                fi
    esac
done
# Setting all options here to be available in .metadata-inventory
OPT_METADATA_INVENTORY="${SUMMARY_REPORT} ${SHOW_FENCE_AGENT_PASSWORDS} ${PG_DB_USER} ${PG_DB_ADDRESS} ${PG_DB_PASSWORD} ${TEMPORARY_DB_NAME} ${ENGINE_DB_USER}"

[ -z "${TAR_FILE}" ] && usage

echo "Preparing environment:"
echo "======================"
echo "Temporary working directory is ${WORK_DIR}"

"$SCRIPT_DIR"/unpackAndPrepareDump.sh "$TAR_FILE" "$WORK_DIR" "${OPT_METADATA_INVENTORY}"
"$SCRIPT_DIR"/unpackHostsSosReports.sh "$WORK_DIR"
"$SCRIPT_DIR"/importDumpIntoNewDb.sh "$WORK_DIR" "${HTML_OUT}" 0>/dev/null

echo
echo "Generating reports:"
echo "==================="
"$WORK_DIR"/produceHtml.sh || echo "html report cannot be generated"

if [ -z "${KEEP_WORKING_DIR}" ]; then
	"$WORK_DIR"/cleanup.sh
else
	"$WORK_DIR"/stopDb.sh
	"$WORK_DIR"/help
fi
