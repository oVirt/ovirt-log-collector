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
--  Find hosts with old CPU as Conroe or Penryn and recommend Nehalem-IBRS
--  or superiror
--
CREATE OR REPLACE FUNCTION __temp_detect_old_cpu_conroe_or_penryn()
  RETURNS TABLE(hostname VARCHAR(255), cluster VARCHAR(40)) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='cluster') THEN
        RETURN QUERY (
        SELECT
            c.name AS cluster,
            s.vds_name AS hostname
        FROM
            vds_dynamic d
        INNER JOIN vds_static s ON d.vds_id = s.vds_id
        INNER JOIN cluster c ON c.cluster_id = s.cluster_id
        WHERE (SELECT count(f) FROM regexp_split_to_table(d.cpu_flags, ',') f
        WHERE f ILIKE '%model_%' AND f <> 'model_Conroe' AND f <> 'model_Penryn') = 0
        );
    ELSE
        -- Compat mode, engine database < 4.0
        RETURN QUERY (
        SELECT
            c.name AS cluster,
            s.vds_name AS hostname
        FROM
            vds_dynamic d
        INNER JOIN vds_static s ON d.vds_id = s.vds_id
        INNER JOIN vds_groups c ON c.vds_group_id = s.vds_group_id
        WHERE (SELECT count(f) FROM regexp_split_to_table(d.cpu_flags, ',') f
        WHERE f ILIKE '%model_%' AND f <> 'model_Conroe' AND f <> 'model_Penryn') = 0
        );
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
    SELECT
        cluster AS "Cluster",
        hostname AS "Hostname"
    FROM
        __temp_detect_old_cpu_conroe_or_penryn()
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_detect_old_cpu_conroe_or_penryn();
