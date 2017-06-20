-- Based on https://github.com/oVirt/ovirt-engine/blob/0d39c2580caf4597cbdbaaa5de0282b24089cb68/packaging/setup/plugins/ovirt-engine-setup/ovirt-engine/upgrade/asynctasks.py#L262
--
CREATE OR REPLACE FUNCTION __temp_query_get_compensation_tasks()
  RETURNS TABLE(command_type VARCHAR(256), entity_type VARCHAR(128)) AS
$PROCEDURE$
BEGIN
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='business_entity_snapshot') THEN
        RETURN QUERY EXECUTE format('
        SELECT
            command_type, entity_type
        FROM
            business_entity_snapshot
       ');
   END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;
SELECT __temp_query_get_compensation_tasks();
DROP FUNCTION __temp_query_get_compensation_tasks();
