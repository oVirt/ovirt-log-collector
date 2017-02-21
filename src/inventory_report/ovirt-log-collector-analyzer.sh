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

function usage() {
cat << __EOF__
Usage: $0 [options] <tar-file>
    --keep-working-dir
        Do not remove the temporary working directory in the end.
    --csv=<file>
        Write csv report to <file>. Defaults to ${CSV_OUT} .
    --html=<file>
        Write html report to <file>. Defaults to ${HTML_OUT} .

Script unpacks sosreport, import it into db and generates csv and html report into current directory.
__EOF__
exit 1;

}

KEEP_WORKING_DIR=
TAR_FILE=
CSV_OUT=analyzer_report.csv
HTML_OUT=analyzer_report.html

while [ -n "$1" ]; do
	x="$1"
	v="${x#*=}"
	shift
	case "${x}" in
		--help)
			usage
		;;
		--keep-working-dir)
			KEEP_WORKING_DIR=1
		;;
                --csv=*)
			CSV_OUT="${v}"
		;;
                --html=*)
			HTML_OUT="${v}"
		;;
		*)
			if [ -r "${x}" ]; then
				TAR_FILE="$(readlink -f "${x}")"
			else
				echo "Invalid option '${x}'"
				exit 1
			fi
		;;
	esac
done

[ -z "${TAR_FILE}" ] && usage

SCRIPT_DIR="$(dirname $(readlink -f $0))"
WORK_DIR="$(mktemp -d)"

echo "Preparing environment:"
echo "======================"
echo "Temporary working directory is ${WORK_DIR}"

"$SCRIPT_DIR"/unpackAndPrepareDump.sh "$TAR_FILE" "$WORK_DIR"
"$SCRIPT_DIR"/importDumpIntoNewDb.sh "$WORK_DIR" "${CSV_OUT}" "${HTML_OUT}" 0>/dev/null

echo
echo "Generating reports:"
echo "==================="
"$WORK_DIR"/produceHtml.sh || echo "html report cannot be generated"
"$WORK_DIR"/produceCsv.sh || echo "csv report cannot be generated"

if [ -z "${KEEP_WORKING_DIR}" ]; then
	"$WORK_DIR"/cleanup.sh
else
	"$WORK_DIR"/stopDb.sh
	"$WORK_DIR"/help
fi
