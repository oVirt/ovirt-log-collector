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
--- Based on: https://github.com/oVirt/ovirt-engine/blob/d1d0d67265313906dc85186ad4a9974b46abffdb/packaging/setup/plugins/ovirt-engine-setup/ovirt-engine/config/aaakerbldap.py#L64
COPY (
    SELECT
        option_value AS "Domain Name"
    FROM
        vdc_options
    WHERE
        option_name='DomainName'
    AND
        option_value <> ''
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
