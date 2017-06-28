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
    psql -h "$PGRUN" "$@"
}

function executeSqlUsingPostgresDb() {
    executeSql -d postgres "$@"
}

function initAndStartDb() {
    mkdir -p "$PGDATA" "$PGRUN";
    local initdblog="${WORK_DIR}/initdb.log"
    echo "Creating a temporary database in $PGDATA. Log of initdb is in ${initdblog}"
    initdb "$PGDATA" > "${initdblog}"

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
        "$WORK_DIR/produceHtml.sh" "$(dirname $0)/produceReport/produceReport.sh \"$WORK_DIR\" | asciidoctor -a toc -o ${HTML_OUT} -;echo \"Generated ${HTML_OUT}\""
    createExecutableBashScript "$WORK_DIR/startDb.sh" "pg_ctl start -D $PGDATA -s -o \"-h '' -k $PGRUN\" -w"
    createExecutableBashScript "$WORK_DIR/stopDb.sh" "pg_ctl stop -D $PGDATA -s -m fast"

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
"

    createExecutableBashScript \
        "$WORK_DIR/help" \
            "cat << __EOF__

Some commands you can use:
==========================
${WORK_DIR}/help
${WORK_DIR}/startDb.sh
psql -h ${WORK_DIR}/postgresDb/pgrun ${DB_NAME}
${WORK_DIR}/produceHtml.sh
${WORK_DIR}/stopDb.sh

When done, to clean up, do:
===========================
${WORK_DIR}/cleanup.sh
__EOF__
"
}
#-----------------------------------------------------------------------------------------------------------------------

DB_NAME="report"
WORK_DIR=$1
HTML_OUT="$2"
initDbVariables
PG_DUMP_DIR=$WORK_DIR/pg_dump_dir
SOS_REPORT_DIR=$WORK_DIR/unpacked_sosreport

createUserScripts

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

COUNT_OF_DBS_HAVING_THIS_NAME=$(executeSqlUsingPostgresDb -A -t -c "SELECT count(datname) FROM pg_database where datname='$DB_NAME';")

if [ $COUNT_OF_DBS_HAVING_THIS_NAME -ne 0 ]; then
    echo "It seems, that db named $DB_NAME already exist. Please enter inexisting db name";
    exit 1;
fi

createRoleIfItDoesNotExist engine
createRoleIfItDoesNotExist postgres

executeSqlUsingPostgresDb -c "create database \"$DB_NAME\" owner \"engine\" template template0 encoding
'UTF8' lc_collate 'en_US.UTF-8' lc_ctype 'en_US.UTF-8';" >> "${WORK_DIR}/sql-log-postgres.log"

cd $PG_DUMP_DIR
restore_log="$WORK_DIR/db-restore.log"
echo "Importing the dump into a temporary database. Log of the restore process is in ${restore_log}"
executeSql -d "$DB_NAME" < $PWD/restore.sql > "${restore_log}" 2>&1
