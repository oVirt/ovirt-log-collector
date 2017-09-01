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
-- Based on: https://github.com/oVirt/ovirt-engine/blob/7914051ad5aadc30894208a5f5dc81a177b91af7/packaging/setup/plugins/ovirt-engine-common/ovirt-engine/system/he.py#L97-L115
--
CREATE OR REPLACE FUNCTION __temp_query_ha_global_maintenance()
  RETURNS TABLE(hypervisor VARCHAR(255), ha_global_maintenance boolean) AS
$PROCEDURE$
BEGIN
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='vds_statistics' and column_name='ha_global_maintenance') THEN
        RETURN QUERY (
        SELECT
            vds.vds_name,
            vds_statistics.ha_global_maintenance
        FROM
            vds_statistics
        INNER JOIN vds ON vds.vds_id=vds_statistics.vds_id AND vds_statistics.ha_global_maintenance='t'
        );
   END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
    SELECT
        hypervisor AS "Hypervisor",
        CASE WHEN ha_global_maintenance THEN 'Yes' ELSE 'No' END AS "Hosted Engine HA is in Global Maintenance mode"
    FROM
        __temp_query_ha_global_maintenance()
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_query_ha_global_maintenance();
