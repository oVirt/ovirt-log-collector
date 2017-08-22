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
--
----------------------------------------------------------------
-- Status for host:
--     0 Unassigned
--     1 Down
--     2 Maintenance
--     3 Up
--     4 NonResponsive
--     5 Error
--     6 Installing
--     7 Failed
--     8 Reboot
--     9 Preparing for maintenance
--     10 Non Operational
--     11 PendingApproval
--     12 Initializing
--     13 Connecting
--     14 InstallingOS
--     15 Kdumping
--
-- All values defined in ovirt-engine project:
-- backend/manager/modules/common/src/main/java/org/ovirt/engine/core/common/businessentities/VDSStatus.java

WITH hosts_unavailable AS (
    SELECT
        vds_name, status
    FROM
        vds
    WHERE status=2 or
          status=5 or
          status=7 or
          status=9 or
          status=10
)
SELECT
    vds_name AS "Host",
    host_status_temp.text AS "Status"
FROM
    hosts_unavailable
LEFT JOIN
    host_status_temp ON hosts_unavailable.status = host_status_temp.id
