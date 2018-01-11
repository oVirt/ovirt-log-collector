
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
--  Find virtual machines with less than 20% of guaranteed memory to start
--  in the hypervisors
--
COPY (
    SELECT
        vm_name AS "Virtual Machine",
        mem_size_mb AS "Memory Size (MB)",
        min_allocated_mem AS "Physical Memory Guaranteed (MB)"
    FROM
        vm_static
    WHERE
        (20 * mem_size_mb / 100) > min_allocated_mem
    AND vm_static.entity_type = 'VM'
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
