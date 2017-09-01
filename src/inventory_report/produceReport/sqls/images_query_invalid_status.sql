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
-- Status based on: https://github.com/oVirt/ovirt-engine/blob/09d1d502c7a616ce2278072b429259a30c16f27c/backend/manager/modules/common/src/main/java/org/ovirt/engine/core/common/businessentities/storage/ImageStatus.java#L9-L12 
COPY (
    SELECT
        vm_static.vm_name AS "Virtual Machine",
        images.image_guid AS "Image GUID",
        CASE WHEN images.imagestatus=2 THEN 'Locked' WHEN images.imagestatus=4 THEN 'Illegal' END AS "Image Status"
    FROM
        images
    INNER JOIN vm_device ON images.image_group_id=vm_device.device_id
    INNER JOIN vm_static ON vm_static.vm_guid=vm_device.vm_id
    AND images.imagestatus IN (4,2)
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
