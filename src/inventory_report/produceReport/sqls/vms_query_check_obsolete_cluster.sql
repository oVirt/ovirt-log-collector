CREATE OR REPLACE FUNCTION __temp_hosts_check_obsolete_cluster()
  RETURNS TABLE(vms bigint) AS
$PROCEDURE$
BEGIN
    -- new versions of database the vds_group_compatibility_version was
    -- renamed to cluster_compatibility_version, if we find it let's use it.
    IF EXISTS (SELECT column_name FROM information_schema.columns WHERE table_name='vms' and column_name='cluster_compatibility_version') THEN
         RETURN QUERY EXECUTE format('
             SELECT
                 COUNT(vm_name)
             FROM
                 vms
             WHERE
                 cluster_compatibility_version <> '''' and
                 cluster_compatibility_version < ''3.6''
         ');
    ELSE
         RETURN QUERY EXECUTE format('
             SELECT
                 COUNT(vm_name)
             FROM
                 vms
             WHERE
                 vds_group_compatibility_version <> '''' and
                 vds_group_compatibility_version < ''3.6''
         ');
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

select __temp_hosts_check_obsolete_cluster();
drop function __temp_hosts_check_obsolete_cluster();
