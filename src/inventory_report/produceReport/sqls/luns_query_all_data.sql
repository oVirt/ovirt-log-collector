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
        storage_name AS "Storage Domain",
        vendor_id AS "Vendor ID",
        product_id AS "Product ID",
        device_size AS "Device Size",
        serial AS "Serial",
        volume_group_id AS "Volume Group ID",
        lun_id AS "Lun ID",
        physical_volume_id AS "Physical Volume ID"
    FROM
        luns_view
) TO STDOUT With CSV DELIMITER E'\|' HEADER;
