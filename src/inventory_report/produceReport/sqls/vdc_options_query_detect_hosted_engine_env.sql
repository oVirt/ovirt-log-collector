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
-- Based on: https://github.com/oVirt/ovirt-engine/blob/7914051ad5aadc30894208a5f5dc81a177b91af7/packaging/setup/plugins/ovirt-engine-common/ovirt-engine/system/he.py#L70-L91
--
COPY (
    SELECT
        vdc_options.option_value AS "Virtual Machine running Engine",
        vds_name AS "Hypervisor running the Virtual Machine"
    FROM
        vdc_options
    INNER JOIN vms ON vms.vm_name=vdc_options.option_value
    INNER JOIN vds ON vds.vds_id=vms.run_on_vds
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
