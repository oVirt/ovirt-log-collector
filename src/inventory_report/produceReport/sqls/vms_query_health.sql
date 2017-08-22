--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
--
----------------------------------------------------------------
-- Status for vms:
--
--  -1 Unassigned,
--   0 Down,
--   1 Up
--   2 PoweringUp
--   4 Paused
--   5 MigratingFrom
--   6 MigratingTo
--   7 Unknown
--   8 NotResponding
--   9 WaitForLaunch
--   10 RebootInProgress
--   11 SavingState
--   12 RestoringState
--   13 Suspended
--   14 ImageIllegal
--   15 ImageLocked
--   16 PoweringDown
--
-- All values defined in ovirt-engine project:
-- backend/manager/modules/common/src/main/java/org/ovirt/engine/core/common/businessentities/VMStatus.java

COPY (
    WITH vms_unavailable AS (
        SELECT
            vm_name,
            status
        FROM
            vms
        WHERE
            status=4 or
            status=14 or
            status=15
    )
    SELECT
        vm_name AS "Virtual Machine",
        vms_status_temp.text AS "Status"
    FROM
        vms_unavailable
    LEFT JOIN
        vms_status_temp ON vms_unavailable.status = vms_status_temp.id
) TO STDOUT With CSV DELIMITER E'\|' HEADER;
