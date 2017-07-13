CREATE OR REPLACE FUNCTION __temp_cluster_show_all()
  RETURNS TABLE(clustername VARCHAR(40), datacentername VARCHAR(40), compatibility VARCHAR(40), cpuname VARCHAR(255)) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='cluster') THEN
        RETURN QUERY (
        SELECT
            c.name  AS "Cluster Name",
            sp.name AS "Data Center Name",
            c.compatibility_version AS "Compatibility Version",
            c.cpu_name AS "Cluster CPU Type"
        FROM
            cluster c
            LEFT OUTER JOIN storage_pool sp ON c.storage_pool_id=sp.id
        ORDER BY c.name
        );
    ELSE
        -- Compat mode, engine database < 4.0
        RETURN QUERY (
        SELECT
            c.name  AS "Cluster Name",
            sp.name AS "Data Center Name",
            c.compatibility_version AS "Compatibility Version",
            c.cpu_name AS "Cluster CPU Type"
        FROM
            vds_groups c
            LEFT OUTER JOIN storage_pool sp ON c.storage_pool_id=sp.id
        ORDER BY c.name
        );
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
  SELECT
      row_number() OVER (ORDER BY clustername NULLs last) AS "NO.",
      clustername AS "Cluster Name",
      datacentername AS "Data Center Name",
      compatibility as "Compatibility Version",
      cpuname AS "Cluster CPU Type"
  FROM
      __temp_cluster_show_all()
  ORDER BY
      clustername
) To STDOUT With CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_cluster_show_all();
