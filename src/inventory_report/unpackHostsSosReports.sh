#!/bin/bash
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

echo "Welcome to unpackHostsSosReports script!"

UNPACKED_SOSREPORT=$1

UNPACK_DIR=$(find "$UNPACKED_SOSREPORT" -name "unpacked_sosreport" 2> /dev/null)
LOG_COLLECTOR_DIR=$(find "$UNPACK_DIR" -name "sosreport-LogCollector*" 2> /dev/null)
LOG_COLLECTOR_DATA_DIR=$(find "$LOG_COLLECTOR_DIR" -name "log-collector-data" 2> /dev/null)

for dir in $LOG_COLLECTOR_DATA_DIR/*/
do
    dir=${dir%*/}
    HOST_SOS_REPORT=$(find "$dir" -name "*.tar.xz" 2> /dev/null)
    if [ -r "${HOST_SOS_REPORT}" ]; then
        dir_sosreport="${HOSTS_SOSREPORT_EXTRACTED_DIR}/${dir##*/}"
        $(mkdir -p ${dir_sosreport})
        echo "Extracting sosreport from hypervisor ${dir##*/} in ${dir_sosreport}"
        tar -C "${dir_sosreport}" -xf "$HOST_SOS_REPORT" &> /dev/null
        chmod -R a+rwx ${HOSTS_SOSREPORT_EXTRACTED_DIR}
        echo
    fi
done
