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
COPY (
    SELECT
        vm_static.vm_name AS "Virtual Machine",
        images.image_guid AS "Image GUID",
        images.image_group_id AS "Image Group ID",
        images.vm_snapshot_id AS "VM Snapshot ID"
    FROM
        images
    INNER JOIN vm_device ON vm_device.device_id=images.image_group_id
    INNER JOIN vm_static ON vm_static.vm_guid=vm_device.vm_id
    AND vm_snapshot_id='00000000-0000-0000-0000-000000000000'
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
