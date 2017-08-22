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
CREATE OR REPLACE FUNCTION __temp_vms_per_cluster()
  RETURNS TABLE(name VARCHAR(40), vms_count bigint) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='cluster') THEN
        RETURN QUERY (
        SELECT
            cluster.name AS "Cluster",
            count(vm_static.vm_name) AS "Number of Virtual Machine(s)"
        FROM
            cluster
        INNER JOIN vm_static ON cluster.cluster_id=vm_static.cluster_id
        AND entity_type = 'VM'
        GROUP BY cluster.name
        ORDER BY cluster.name
        );
    ELSE
        -- Compat mode, engine database < 4.0
        RETURN QUERY (
        SELECT
             vds_groups.name AS "Cluster",
            count(vm_static.vm_name) AS "Number of Virtual Machine(s)"
        FROM
            vds_groups
        INNER JOIN vm_static ON vds_groups.vds_group_id=vm_static.vds_group_id
        AND entity_type = 'VM'
        GROUP BY vds_groups.name
        ORDER BY vds_groups.name
        );
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

Copy (
  SELECT
    row_number() OVER (ORDER BY name NULLs last) AS "NO.",
    name AS "Cluster",
    vms_count AS "Number of Virtual Machine(s)"
  FROM
    __temp_vms_per_cluster()
  ORDER BY
    name
) To STDOUT With CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_vms_per_cluster();
