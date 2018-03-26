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
CREATE OR REPLACE FUNCTION __temp_cluster_migration_policy_legacy()
  RETURNS TABLE(clustername VARCHAR(40), datacentername VARCHAR(40)) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='cluster') THEN
        IF EXISTS (SELECT column_name
                   FROM information_schema.columns
                   WHERE table_name='cluster' AND column_name='migration_policy_id') THEN
            RETURN QUERY (
                SELECT
                    c.name  AS "Cluster Name",
                    sp.name AS "Data Center Name"
                FROM
                    cluster c
                INNER JOIN storage_pool sp ON c.storage_pool_id=sp.id AND
                migration_policy_id IS NULL OR migration_policy_id='00000000-0000-0000-0000-000000000000'
                ORDER BY c.name
            );
        END IF;
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
    SELECT
        row_number() OVER (ORDER BY clustername NULLs last) AS "NO.",
        clustername AS "Cluster",
        datacentername AS "Data Center"
    FROM
        __temp_cluster_migration_policy_legacy()
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_cluster_migration_policy_legacy();
