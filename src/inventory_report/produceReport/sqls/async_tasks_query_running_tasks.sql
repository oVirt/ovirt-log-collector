-- Based on https://github.com/oVirt/ovirt-engine/blob/fc6345814fa71898294850b92e1f6350b198b821/packaging/setup/plugins/ovirt-engine-setup/ovirt-engine/upgrade/asynctasks.py#L161
--
CREATE OR REPLACE FUNCTION __temp_query_async_tasks_running()
  RETURNS TABLE(action_type integer, task_id uuid, storagepool_name VARCHAR(40)) AS
$PROCEDURE$
BEGIN
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='async_tasks' and column_name='storage_pool_id') THEN
        RETURN QUERY EXECUTE format('
        SELECT
            async_tasks.action_type,
            async_tasks.task_id,
            storage_pool.name
        FROM
            async_tasks, storage_pool
        WHERE
            async_tasks.storage_pool_id = storage_pool.id
       ');
   END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;
SELECT __temp_query_async_tasks_running();
DROP FUNCTION __temp_query_async_tasks_running();
