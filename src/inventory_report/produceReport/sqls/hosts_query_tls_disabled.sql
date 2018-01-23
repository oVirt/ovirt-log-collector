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
CREATE OR REPLACE FUNCTION __temp_hosts_tls_disabled()
  RETURNS TABLE(name VARCHAR(255), cluster VARCHAR(40), tls boolean) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='cluster') THEN
        RETURN QUERY (
        SELECT
            vds_name AS "Hostname",
            cluster_name AS "Cluster",
            server_ssl_enabled AS "TLS Protocol"
        FROM
            vds
        WHERE server_ssl_enabled IS FALSE
        );
    ELSE
        -- Compat mode, engine database < 4.0
        RETURN QUERY (
        SELECT
            vds_name AS "Hostname",
            vds_group_name AS "Cluster",
            server_ssl_enabled AS "TLS Protocol"
        FROM
            vds
        WHERE server_ssl_enabled IS FALSE
        );
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
  SELECT
      row_number() OVER (ORDER BY name NULLs last) AS "NO.",
      name AS "Hostname",
      cluster AS "Cluster",
      CASE WHEN tls THEN 'Yes' ELSE 'No' END AS "TLS Protocol"
  FROM
      __temp_hosts_tls_disabled()
  ORDER BY
    name
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_hosts_tls_disabled();
