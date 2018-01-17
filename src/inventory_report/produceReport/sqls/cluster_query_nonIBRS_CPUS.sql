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
CREATE OR REPLACE FUNCTION __temp_cluster_nonIBRS_CPUS()
  RETURNS TABLE(cluster_name VARCHAR(40), cpu VARCHAR(255)) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='cluster') THEN
        RETURN QUERY (
        SELECT
            name AS cluster,
            cpu_name AS detected_cpu
        FROM
            vds_groups
        WHERE cpu_name NOT ILIKE '%IBRS%'
        );
    ELSE
        -- Compat mode, engine database < 4.0
        RETURN QUERY (
        SELECT
            name AS cluster,
            cpu_name AS detected_cpu
        FROM
            vds_groups
        WHERE cpu_name NOT ILIKE '%IBRS%'
        );
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;
COPY (
    SELECT
        row_number() OVER (ORDER BY cluster_name NULLs last) AS "NO.",
        cluster_name AS "Cluster",
        cpu AS "Detected CPU"
    FROM
        __temp_cluster_nonIBRS_CPUS()
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
DROP FUNCTION __temp_cluster_nonIBRS_CPUS();
