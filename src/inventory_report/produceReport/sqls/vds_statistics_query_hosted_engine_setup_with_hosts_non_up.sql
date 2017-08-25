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
-- Capture hypervisors from Hosted Engine setup which are not in Up status
--
-- Status based on Engine project:
-- backend/manager/modules/common/src/main/java/org/ovirt/engine/core/common/businessentities/VDSStatus.java
CREATE OR REPLACE FUNCTION __temp_query_ha_configured_host_no_up()
  RETURNS TABLE(hypervisor VARCHAR(255), ha_active boolean, ha_configured boolean, local_maintenance boolean, global_maintenance boolean, status integer) AS
$PROCEDURE$
BEGIN
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='vds_statistics' and column_name='ha_configured') THEN
        RETURN QUERY (
        SELECT
            vds.vds_name,
            vds_statistics.ha_active,
            vds_statistics.ha_configured,
            vds_statistics.ha_local_maintenance,
            vds_statistics.ha_global_maintenance,
            vds.status
        FROM
            vds_statistics
        INNER JOIN vds ON vds.vds_id=vds_statistics.vds_id AND
                   vds_statistics.ha_local_maintenance IS FALSE AND
                   vds_statistics.ha_global_maintenance IS FALSE AND
                   vds_statistics.ha_active IS TRUE AND
                   vds_statistics.ha_configured IS TRUE AND
                   vds.status <> 3
        );
   END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
    SELECT
        hypervisor AS "Hypervisor",
        CASE WHEN ha_active THEN 'Yes' ELSE 'No' END AS "HA Active",
        CASE WHEN ha_configured THEN 'Yes' ELSE 'No' END AS "HA Configured",
        CASE WHEN local_maintenance THEN 'Yes' ELSE 'No' END AS "Local Maintenance",
        CASE WHEN global_maintenance THEN 'Yes' ELSE 'No' END AS "Global Maintenance",
        CASE WHEN status=0 THEN 'Unassigned'
             WHEN status=1 THEN 'Down'
             WHEN status=2 THEN 'Maintenance'
             WHEN status=3 THEN 'Up'
             WHEN status=4 THEN 'NonResponsive'
             WHEN status=5 THEN 'Error'
             WHEN status=6 THEN 'Installing'
             WHEN status=7 THEN 'InstallFailed'
             WHEN status=8 THEN 'Reboot'
             WHEN status=9 THEN 'PreparingForMaintenance'
             WHEN status=10 THEN 'NonOperational'
             WHEN status=11 THEN 'PendingApproval'
             WHEN status=12 THEN 'Initializing'
             WHEN status=13 THEN 'Connecting'
             WHEN status=14 THEN 'InstallingOS'
             WHEN status=15 THEN 'Kdumping'
        END AS "Status"
    FROM
        __temp_query_ha_configured_host_no_up()
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_query_ha_configured_host_no_up();
