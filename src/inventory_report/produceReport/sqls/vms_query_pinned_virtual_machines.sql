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
--  Return the virtual machines pinned to run in a specific host.
--
--  The column dedicated_vm_for_vd from vm_static can contain a single
--  hypervisor entry or multiple hypervisors (using delimiter comma).
--  Based on that, we are extacting the hypervisors in the WITH statement
--  and using it in the INNER JOIN.
--
COPY (
    WITH vms_pinned AS (
        SELECT
            vm_name,
            unnest(string_to_array(dedicated_vm_for_vds,',')) AS dedicated_vds
        FROM
            vm_static
        WHERE
            vm_static.dedicated_vm_for_vds IS NOT NULL
        AND vm_static.entity_type='VM'
    )
    SELECT
        vms_pinned.vm_name AS "Virtual Machine",
        vds.vds_name AS "Hypervisor"
    FROM
        vds
    INNER JOIN vms_pinned ON vds.vds_id::text=vms_pinned.dedicated_vds ORDER BY vms_pinned.vm_name
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
