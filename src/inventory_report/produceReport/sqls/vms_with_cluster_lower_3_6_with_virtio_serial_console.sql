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
CREATE OR REPLACE FUNCTION __temp_vms_lower_3_6_cluster_with_virtio_serial_console()
  RETURNS TABLE(name VARCHAR(255)) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='cluster') THEN
        RETURN QUERY EXECUTE format('
        SELECT
            DISTINCT vm_name
        FROM
            vm_static,
            vm_device
        WHERE
            vm_device.type=''console'' AND
            vm_device.device=''console'' AND
            vm_static.cluster_id IN (
                SELECT
                    cluster_id
                FROM
                    cluster
                WHERE
                    compatibility_version <= ''3.5''
            )
        ');
    ELSE
        -- Compat mode, engine database < 4.0
        RETURN QUERY EXECUTE format('
        SELECT
            DISTINCT vm_name
        FROM
            vm_static,
            vm_device
        WHERE
            vm_device.type=''console'' AND
            vm_device.device=''console'' AND
            vm_static.vds_group_id IN (
                SELECT
                    vds_group_id
                FROM
                    vds_groups
                WHERE
                    compatibility_version <= ''3.5''
            )
        ');
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;
SELECT __temp_vms_lower_3_6_cluster_with_virtio_serial_console();
DROP FUNCTION __temp_vms_lower_3_6_cluster_with_virtio_serial_console();
