CREATE OR REPLACE FUNCTION __temp_minimum_cluster_compat_level()
  RETURNS TABLE(cluster_name VARCHAR(40), cluster_compat_version VARCHAR(40)) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='cluster') THEN
        RETURN QUERY (
        SELECT
            name AS "Cluster",
            compatibility_version AS "Compatibility Version"
        FROM
            cluster
        WHERE
            compatibility_version <> '' AND
            compatibility_version < '3.6'
        );
    ELSE
        -- Compat mode, engine database < 4.0
        RETURN QUERY (
        SELECT
            name AS "Cluster",
            compatibility_version AS "Compatibility Version"
        FROM
            vds_groups
        WHERE
            compatibility_version <> '' AND
            compatibility_version < '3.6'
        );
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

Copy (
  SELECT
    row_number() OVER (ORDER BY cluster_name NULLs last) AS "NO.",
    cluster_name AS "Cluster",
    cluster_compat_version AS "Compatibility Version"
  FROM
    __temp_minimum_cluster_compat_level()
  ORDER BY
    cluster_name
) To STDOUT With CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_minimum_cluster_compat_level();
