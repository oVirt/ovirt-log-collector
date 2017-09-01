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
-- Based on https://github.com/oVirt/ovirt-engine/blob/0d39c2580caf4597cbdbaaa5de0282b24089cb68/packaging/setup/plugins/ovirt-engine-setup/ovirt-engine/upgrade/asynctasks.py#L262
--
CREATE OR REPLACE FUNCTION __temp_query_get_compensation_tasks()
  RETURNS TABLE(cmd_type VARCHAR(256), ent_type VARCHAR(128)) AS
$PROCEDURE$
BEGIN
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='business_entity_snapshot') THEN
        RETURN QUERY (
        SELECT
            command_type,
            entity_type
        FROM
            business_entity_snapshot
        );
   END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
    SELECT
        cmd_type AS "Command Type",
        ent_type AS "Entity Type"
    FROM
        __temp_query_get_compensation_tasks()
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_query_get_compensation_tasks();
