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
-- Based on https://github.com/oVirt/ovirt-engine/blob/fc6345814fa71898294850b92e1f6350b198b821/packaging/setup/plugins/ovirt-engine-setup/ovirt-engine/upgrade/asynctasks.py#L161
--
CREATE OR REPLACE FUNCTION __temp_query_async_tasks_running()
  RETURNS TABLE(action_type integer, task_id uuid, storagepool_name VARCHAR(40)) AS
$PROCEDURE$
BEGIN
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='async_tasks' and column_name='storage_pool_id') THEN
        RETURN QUERY (
        SELECT
            async_tasks.action_type,
            async_tasks.task_id,
            storage_pool.name
        FROM
            async_tasks, storage_pool
        WHERE
            async_tasks.storage_pool_id=storage_pool.id
        );
   END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
    SELECT
        action_type AS "Action Type",
        task_id AS "Task UUID",
        storagepool_name AS "Data Center"
    FROM
        __temp_query_async_tasks_running()
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_query_async_tasks_running();
