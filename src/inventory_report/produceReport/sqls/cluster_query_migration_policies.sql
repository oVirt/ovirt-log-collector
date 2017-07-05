CREATE OR REPLACE FUNCTION __temp_cluster_migration_policies()
  RETURNS TABLE(name VARCHAR(40), policyname VARCHAR(128), properties text) AS
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
            cluster_policies.name AS "Policy Name",
            regexp_replace(cluster_policies.custom_properties, '"|{|}|\n|(:)|(^ .)|, |', '', 'g') AS "Properties"
        FROM
            cluster
        INNER JOIN cluster_policies ON cluster.cluster_policy_id=cluster_policies.id
        );
    ELSE
        -- Compat mode, engine database < 4.0
        RETURN QUERY (
        SELECT
            vds_groups.name AS "Cluster Name",
            cluster_policies.name AS "Policy Name",
            regexp_replace(cluster_policies.custom_properties, '"|{|}|\n|(:)|(^ .)|, |', '', 'g') AS "Properties"
        FROM
            vds_groups
        INNER JOIN cluster_policies ON vds_groups.cluster_policy_id=cluster_policies.id
        );
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
  SELECT
    row_number() OVER (ORDER BY name NULLs last) AS "NO.",
    name AS "Cluster",
    policyname AS "Policy Name",
    properties AS "Properties"
  FROM
    __temp_cluster_migration_policies()
  ORDER BY
    name
) To STDOUT With CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_cluster_migration_policies();
