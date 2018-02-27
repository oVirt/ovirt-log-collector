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
. ${SCRIPT_DIR}/inventory-profile

if [ $# -ne 2 ]; then
cat << __EOF__
Usage: $0 <analyzer-working-dir> <html-out-file>

Script generates from db adoc file describing current system.
__EOF__

	exit 1;
fi

function initDbVariables() {
    DBDIR=$WORK_DIR/postgresDb

    PGDATA=$DBDIR/pgdata
    PGRUN=$DBDIR/pgrun
}

function executeSql() {
    # If engine_address is not set it is local env
    if [ -z "${PG_DB_ADDRESS}" ]; then
        ${PSQL_CMD} -h "$PGRUN" "$@"
    else
        PGPASSWORD=${PG_DB_PASSWORD} ${PSQL_CMD} -h ${PG_DB_ADDRESS} -U ${PG_DB_USER} "$@"
    fi
}

function executeSqlUsingPostgresDb() {
    executeSql -d postgres "$@"
}

function initAndStartDb() {
    mkdir -p "$PGDATA" "$PGRUN";
    local initdblog="${WORK_DIR}/initdb.log"
    echo "Creating a temporary database in $PGDATA. Log of initdb is in ${initdblog}"

    ${INITDB_CMD} "${PGDATA}" > "${initdblog}"

    $WORK_DIR/startDb.sh
}

function createRoleIfItDoesNotExist() {
    if [ $(executeSqlUsingPostgresDb -t -A -c "select usename from pg_user where usename='$1';" | wc -l) -ne 1 ]; then
        executeSqlUsingPostgresDb -c "create user $1 password '$1';" >> "${WORK_DIR}/sql-log-postgres.log"
    fi
}

#2 parameters: script name, script body.
function createExecutableBashScript() {
    echo -e "#!/bin/bash\n$2" > "$1"
    chmod u+x $1
}

function createUserScripts() {
    createExecutableBashScript \
        "$WORK_DIR/produceHtml.sh" "$(dirname $0)/produceReport/produceReport.sh \"$WORK_DIR\" | asciidoctor -a toc=left -o ${HTML_OUT} -;echo \"Generated ${HTML_OUT}\""

    createExecutableBashScript \
        "$WORK_DIR/cleanup.sh" \
        "
echo
echo \"Cleaning up:\"
echo \"============\"
echo \"Stopping temporary database\"
\"$WORK_DIR\"/stopDb.sh
echo \"Removing temporary directory \"$WORK_DIR\"\"
rm -rf \"$WORK_DIR\"
rm -rf \"${HOSTS_SOSREPORT_EXTRACTED_DIR}\"
"
    # If engine_address is not set it is local env
    if [ -z "${PG_DB_ADDRESS}" ]; then
        createExecutableBashScript "$WORK_DIR/startDb.sh" "${PG_CTL_CMD} start -D $PGDATA -s -o \"-h '' -k $PGRUN\" -w"
        createExecutableBashScript "$WORK_DIR/stopDb.sh" "${PG_CTL_CMD} stop -D $PGDATA -s -m fast"

        createExecutableBashScript \
            "$WORK_DIR/help" \
            "cat << __EOF__

Some commands you can use:
==========================
${WORK_DIR}/help
${WORK_DIR}/startDb.sh
${PSQL_CMD} -h ${WORK_DIR}/postgresDb/pgrun ${TEMPORARY_DB_NAME}
${WORK_DIR}/produceHtml.sh
${WORK_DIR}/stopDb.sh

When done, to clean up, do:
===========================
${WORK_DIR}/cleanup.sh
__EOF__
"
    else
        # REMOTE DB
        createExecutableBashScript "$WORK_DIR/stopDb.sh" "PGPASSWORD=${PG_DB_PASSWORD} ${PSQL_CMD} -h ${PG_DB_ADDRESS} -U ${PG_DB_USER} -c \"DROP DATABASE ${TEMPORARY_DB_NAME}\" &> /dev/null"
        createExecutableBashScript \
            "$WORK_DIR/help" \
            "cat << __EOF__

Some commands you can use:
==========================
${WORK_DIR}/help
${WORK_DIR}/produceHtml.sh

When done, to clean up, do:
===========================
${WORK_DIR}/cleanup.sh
__EOF__
"
    fi
}
#-----------------------------------------------------------------------------------------------------------------------

WORK_DIR=$1
HTML_OUT="$2"
# If engine_address is not set it is local env
if [ -z "${PG_DB_ADDRESS}" ]; then
    initDbVariables
fi
PG_DUMP_DIR=$WORK_DIR/pg_dump_dir
SOS_REPORT_DIR=$WORK_DIR/unpacked_sosreport

. "${WORK_DIR}"/.metadata-inventory

createUserScripts

# If engine_address is not set it is local env
if [ -z "${PG_DB_ADDRESS}" ]; then
    if [ ! -d "$PGDATA" -o ! -d "$PGRUN" ]; then
        initAndStartDb
    else
        #try to connect to existing db

        if [ $(executeSqlUsingPostgresDb -c '\l' 1>/dev/null 2>/dev/null; echo $?) -ne 0 ]; then
            cat << __EOF__
It seems, that db directories $PGDATA and $PGRUN exist, but we cannot connect to that db.
Please enter inexisting different directory in which we will create new DB,\
or make sure we can connect to db in this one.
__EOF__
            exit 1;
        fi
    fi

    COUNT_OF_DBS_HAVING_THIS_NAME=$(executeSqlUsingPostgresDb -A -t -c "SELECT count(datname) FROM pg_database where datname='${TEMPORARY_DB_NAME}';")

    if [ $COUNT_OF_DBS_HAVING_THIS_NAME -ne 0 ]; then
        echo "It seems, that db named ${TEMPORARY_DB_NAME} already exist. Please enter inexisting db name";
        exit 1;
    fi
fi

createRoleIfItDoesNotExist "${ENGINE_DB_USER}"
createRoleIfItDoesNotExist postgres

executeSqlUsingPostgresDb -c "create database \"${TEMPORARY_DB_NAME}\" owner \"${ENGINE_DB_USER}\" template template0 encoding
'UTF8' lc_collate 'en_US.UTF-8' lc_ctype 'en_US.UTF-8';" >> "${WORK_DIR}/sql-log-postgres.log"

# If engine_address is not set it is local env
if [ -z "${PG_DB_ADDRESS}" ]; then
    cd $PG_DUMP_DIR
    restore_log="$WORK_DIR/db-restore.log"
    echo "Importing the dump into a temporary database. Log of the restore process is in ${restore_log}"
    executeSql -d "${TEMPORARY_DB_NAME}" < $PWD/restore.sql > "${restore_log}" 2>&1
else
    # Remote DB
    echo "Importing the dump into a temporary database in ${PG_DB_ADDRESS} as ${PG_DB_USER}. Log of the restore process is in ${restore_log}"

    # Using the || exit 0 as pg_restore is exiting the script if there is an error, like "plpgsql" already exists
    PGPASSWORD=${PG_DB_PASSWORD} pg_restore -h ${PG_DB_ADDRESS} -U ${PG_DB_USER} -d ${TEMPORARY_DB_NAME} -F t ${PG_DUMP_TAR} 2> /dev/null || true
fi
