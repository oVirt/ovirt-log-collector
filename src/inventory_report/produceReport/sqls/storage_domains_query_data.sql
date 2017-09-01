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
        row_number() OVER (ORDER BY sds.storage_name NULLs last) AS "NO.",
        sds.storage_name AS "Storage Domain",
        sds.storage_pool_name AS "Data Center",
        stt.text AS "Type",
        sdtt.text AS "Storage Domain Type",
        sds.available_disk_size AS "Available disk size (GB)",
        sds.used_disk_size AS "Used disk size (GB)",
        sum(sds.available_disk_size + sds.used_disk_size) AS "Total disk size (GB)",
        count(image_storage_domain_map.image_id) AS "Number of disks"
    FROM
        storage_domains sds
    JOIN storage_type_temp stt ON sds.storage_type=stt.id
    JOIN storage_domain_type_temp sdtt ON sds.storage_domain_type=sdtt.id
    JOIN image_storage_domain_map ON sds.id=image_storage_domain_map.storage_domain_id
    GROUP BY
        sds.storage_name, sds.storage_pool_name, sds.available_disk_size, sds.used_disk_size, stt.text, sdtt.text
    ORDER BY
        sds.storage_name
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
