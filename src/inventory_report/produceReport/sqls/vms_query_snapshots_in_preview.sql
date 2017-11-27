
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
        snapshots.description AS "Snapshot Description",
        snapshots.snapshot_id AS "Snapshot UUID"
    FROM
        vm_static
    INNER JOIN snapshots ON vm_static.vm_guid=snapshots.vm_id
    WHERE
        snapshots.status = 'IN_PREVIEW'
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
