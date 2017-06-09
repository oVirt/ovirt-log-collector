CREATE OR REPLACE FUNCTION __temp_cluster_check_datacenter_assigned()
  RETURNS TABLE(name VARCHAR(40)) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='cluster') THEN
        RETURN QUERY EXECUTE format('
        SELECT
            name
        FROM
            cluster
        WHERE
            storage_pool_id IS NULL
        ');
    ELSE
        -- Compat mode, engine database < 4.0
        RETURN QUERY EXECUTE format('
        SELECT
            name
        FROM
            vds_groups
        WHERE
            storage_pool_id IS NULL
        ');
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;
SELECT __temp_cluster_check_datacenter_assigned();
DROP FUNCTION __temp_cluster_check_datacenter_assigned();
