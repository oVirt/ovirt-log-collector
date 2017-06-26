CREATE OR REPLACE FUNCTION __temp_vms_per_cluster()
  RETURNS TABLE(name VARCHAR(40), vms_count bigint) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='cluster') THEN
        RETURN QUERY EXECUTE format('
        SELECT
            cluster.name AS "Cluster",
            count(vm_static.vm_name) AS "Number of VMs"
        FROM
            cluster
        INNER JOIN vm_static ON cluster.cluster_id=vm_static.cluster_id
        GROUP BY cluster.name
        ');
    ELSE
        -- Compat mode, engine database < 4.0
        RETURN QUERY EXECUTE format('
        SELECT
            vds_groups.name AS "Cluster",
            count(vm_static.vm_name) AS "Number of VMs"
        FROM
            vds_groups
        INNER JOIN vm_static ON vds_groups.vds_group_id=vm_static.vds_group_id
        GROUP BY vds_groups.name
        ');
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;
SELECT __temp_vms_per_cluster();
DROP FUNCTION __temp_vms_per_cluster();
