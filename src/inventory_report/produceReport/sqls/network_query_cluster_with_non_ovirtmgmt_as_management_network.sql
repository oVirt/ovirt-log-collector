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
CREATE OR REPLACE FUNCTION __temp_non_ovirtmgmt_as_management_network()
  RETURNS TABLE(cluster_name VARCHAR(40), network_name VARCHAR(50)) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='cluster') THEN
        RETURN QUERY (
        SELECT
            cluster.name AS "Cluster Name",
            network.name AS "Management Network"
        FROM
            network
        INNER JOIN network_cluster ON network_cluster.network_id=network.id
        INNER JOIN cluster ON network_cluster.cluster_id=cluster.cluster_id
        AND network_cluster.management='t'
        AND network.name!='ovirtmgmt'
        );
    ELSE
        -- Compat mode, engine database < 4.0
        RETURN QUERY (
        SELECT
            vds_groups.name AS "Cluster Name",
            network.name AS "Management Network"
        FROM
            network
        INNER JOIN network_cluster ON network_cluster.network_id=network.id
        INNER JOIN vds_groups ON network_cluster.cluster_id=vds_groups.vds_group_id
        AND network.description='Management Network'
        AND network.name!='ovirtmgmt'
        );
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
    SELECT
        row_number() OVER (ORDER BY cluster_name NULLs last) AS "NO.",
        cluster_name AS "Cluster",
        network_name AS "Management Network"
    FROM
        __temp_non_ovirtmgmt_as_management_network()
    ORDER BY
       cluster_name
) TO STDOUT With CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_non_ovirtmgmt_as_management_network();
